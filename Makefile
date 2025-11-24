.PHONY: all preview build clean clean-all infrastructure data etl

all: data

preview:
	yarn preview

build:
	yarn build

# ==============================================================================
# STAGE 1: Infrastructure Database (LOCAL ONLY - Run manually every few months)
# ==============================================================================

# Download OGIM v2.7 database from Zenodo (2.9 GB)
data/OGIM_v2.7.gpkg:
	@mkdir -p $(@D)
	@echo "Downloading OGIM v2.7 database from Zenodo (2.9 GB)..."
	@curl -sL -o $@ https://zenodo.org/records/15103476/files/OGIM_v2.7.gpkg
	@echo "✓ OGIM database downloaded"

# Download Texas RRC data files from MFT server
data/p4f606.ebc.gz:
	@mkdir -p $(@D)
	@echo "Downloading P-4 database from Texas RRC..."
	@uv run scripts/download_rrc.py data p4f606.ebc.gz

data/orf850.ebc.gz:
	@mkdir -p $(@D)
	@echo "Downloading P-5 organization data from Texas RRC..."
	@uv run scripts/download_rrc.py data orf850.ebc.gz

data/dbf900.ebc.gz:
	@mkdir -p $(@D)
	@echo "Downloading wellbore database from Texas RRC..."
	@uv run scripts/download_rrc.py data dbf900.ebc.gz

# Build optimized infrastructure-only database (no plumes)
data/infrastructure.duckdb: data/OGIM_v2.7.gpkg data/p4f606.ebc.gz data/orf850.ebc.gz data/dbf900.ebc.gz
	@echo "════════════════════════════════════════════════════════════════"
	@echo "Building infrastructure database (LOCAL ONLY)"
	@echo "This runs infrequently (~every few months) to update facilities"
	@echo "════════════════════════════════════════════════════════════════"
	@echo "1/6 Creating schema..."
	@duckdb $@ < queries/schema.sql
	@echo "2/6 Loading infrastructure from OGIM (wells, compressors, processing, tanks)..."
	@duckdb $@ < queries/load_ogim.sql
	@echo "3/6 Parsing and loading Texas RRC P-4 data (purchaser/gatherer info)..."
	@uv run scripts/create_p4_db.py
	@duckdb $@ < queries/load_p4.sql
	@echo "4/6 Parsing and loading Texas RRC P-5 data (organization names)..."
	@uv run scripts/create_p5_db.py
	@duckdb $@ < queries/load_p5.sql
	@echo "5/6 Parsing and loading Texas RRC wellbore data (API→lease mappings)..."
	@uv run scripts/create_wellbore_db.py
	@duckdb $@ < queries/load_wellbore.sql
	@echo "6/6 Creating spatial indexes and optimizing..."
	@duckdb $@ -c "INSTALL spatial; LOAD spatial; CREATE INDEX IF NOT EXISTS idx_wellbore_location_geom ON wellbore.location USING RTREE (geom); CREATE INDEX IF NOT EXISTS idx_p4_gpn_lease ON p4.gpn (oil_gas_code, district, lease_rrcid); CREATE INDEX IF NOT EXISTS idx_p4_gpn_number ON p4.gpn (gpn_number);"
	@duckdb $@ -c "VACUUM; ANALYZE;"
	@echo "✓ Infrastructure database complete: $@"
	@ls -lh $@

.PHONY: infrastructure
infrastructure: data/infrastructure.duckdb
	@echo "Infrastructure database ready. Upload to GitHub Releases for CI/CD use."

# ==============================================================================
# STAGE 2: ETL Pipeline (GITHUB ACTIONS - Runs frequently)
# ==============================================================================

# Download infrastructure database from GitHub Releases (or copy locally for testing)
data/infrastructure.duckdb.gz:
	@mkdir -p $(@D)
	@if [ ! -f data/infrastructure.duckdb ]; then \
		echo "Downloading infrastructure database from GitHub Releases..."; \
		gh release download latest -p infrastructure.duckdb.gz -D data || \
		(echo "ERROR: No infrastructure.duckdb found locally and failed to download from GitHub Releases" && exit 1); \
	else \
		echo "Using local infrastructure.duckdb (for testing)"; \
		gzip -c data/infrastructure.duckdb > $@; \
	fi

# Download recent plumes from Carbon Mapper
data/plumes_latest.zip:
	@mkdir -p $(@D)
	@echo "Downloading latest plumes from Carbon Mapper..."
	@YEAR=$$(date +%Y) && \
	START_DATE="$$YEAR-01-01" && \
	END_DATE=$$(date +%Y-%m-%d) && \
	curl -sL -o $@ "https://s3.us-west-1.amazonaws.com/msf.data/exports/plumes_$${START_DATE}_$${END_DATE}.zip"
	@echo "✓ Latest plumes downloaded"

data/plumes_latest.csv: data/plumes_latest.zip
	@echo "Extracting plumes CSV..."
	@unzip -o $< -d data/
	@YEAR=$$(date +%Y) && mv data/plumes_$$YEAR-*.csv $@ 2>/dev/null || true
	@touch $@
	@echo "✓ Plumes CSV extracted"

# ETL: Download infrastructure, load plumes, run attribution, export results
.PHONY: data
data:
	@echo "════════════════════════════════════════════════════════════════"
	@echo "Running ETL pipeline (GitHub Actions compatible)"
	@echo "════════════════════════════════════════════════════════════════"
	@# Download infrastructure database from GitHub Releases if not present
	@if [ ! -f data/infrastructure.duckdb ]; then \
		echo "Downloading infrastructure.duckdb from GitHub Releases..."; \
		mkdir -p data; \
		gh release download latest -p infrastructure.duckdb.gz -D data && gunzip data/infrastructure.duckdb.gz || \
		(echo "ERROR: No infrastructure database. Run 'make infrastructure' locally and upload to releases." && exit 1); \
	fi
	@# Download latest plumes
	@$(MAKE) data/plumes_latest.csv
	@# Run ETL
	@rm -f data/data.duckdb
	@echo "1/4 Copying infrastructure database..."
	@cp data/infrastructure.duckdb data/data.duckdb
	@echo "2/4 Loading plumes from Carbon Mapper..."
	@duckdb data/data.duckdb < queries/load_emissions.sql
	@echo "3/4 Running attribution analysis..."
	@duckdb data/data.duckdb -c "INSTALL spatial; LOAD spatial; CREATE INDEX IF NOT EXISTS idx_emissions_sources_geom ON emissions.sources USING RTREE (geom);"
	@duckdb data/data.duckdb < queries/create_attribution.sql
	@echo "4/4 Exporting results for notebook..."
	@mkdir -p data
	@duckdb data/data.duckdb -c "COPY ($$(cat queries/exports/plumes.sql)) TO 'data/plumes.json' (FORMAT JSON, ARRAY true)"
	@duckdb data/data.duckdb -c "COPY ($$(cat queries/exports/infrastructure.sql)) TO 'data/infrastructure.json' (FORMAT JSON, ARRAY true)"
	@echo "✓ ETL pipeline complete"
	@ls -lh data/*.json

# ==============================================================================
# Utilities
# ==============================================================================

clean:
	rm -f data/data.duckdb
	rm -f data/plumes.json data/infrastructure.json data/*.parquet
	rm -f /tmp/root.csv /tmp/info.csv /tmp/gpn.csv /tmp/lease_name.csv
	rm -f /tmp/p5_org.csv /tmp/p5_specialty.csv /tmp/p5_officer.csv /tmp/p5_activity.csv
	rm -f /tmp/wellbore_root.csv /tmp/wellbore_location.csv /tmp/wellbore_wellid.csv

clean-all: clean
	rm -f data/OGIM_v2.7.gpkg data/plumes_latest.zip data/plumes_latest.csv
	rm -f data/p4f606.ebc.gz data/orf850.ebc.gz data/dbf900.ebc.gz
	rm -f data/infrastructure.duckdb data/infrastructure.duckdb.gz
