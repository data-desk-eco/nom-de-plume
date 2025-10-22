.PHONY: all clean clean-all

all: output/lng_attribution.csv

# Download OGIM v2.7 database from Zenodo (2.9 GB)
data/OGIM_v2.7.gpkg:
	@mkdir -p $(@D)
	@echo "Downloading OGIM v2.7 database from Zenodo (2.9 GB)..."
	@curl -sL -o $@ https://zenodo.org/records/15103476/files/OGIM_v2.7.gpkg
	@echo "✓ OGIM database downloaded"

# Download plumes dataset from Carbon Mapper (2025 CH4 plumes)
data/plumes_2025-01-01_2025-10-01.zip:
	@mkdir -p $(@D)
	@echo "Downloading plumes dataset from Carbon Mapper S3 (2025)..."
	@curl -sL -o $@ "https://s3.us-west-1.amazonaws.com/msf.data/exports/plumes_2025-01-01_2025-10-01.zip"
	@echo "✓ Plumes dataset downloaded"

# Extract plumes CSV from zip file
data/plumes_2025-01-01_2025-10-01.csv: data/plumes_2025-01-01_2025-10-01.zip
	@echo "Extracting plumes CSV..."
	@unzip -o $< -d data/
	@touch $@
	@echo "✓ Plumes CSV extracted"

# Texas RRC data files (p4f606.ebc.gz, orf850.ebc.gz, dbf900.ebc.gz)
# must be downloaded manually from https://mft.rrc.texas.gov/ and placed in data/
# The download links require active browser sessions and cannot be automated

# Create DuckDB database from OGIM GeoPackage and Carbon Mapper plumes
# Depends on: data files + database creation queries (schema, loading)
# Does NOT depend on: attribution or LNG analysis queries (use separate targets for those)
data/data.duckdb: data/OGIM_v2.7.gpkg data/plumes_2025-01-01_2025-10-01.csv data/p4f606.ebc.gz data/orf850.ebc.gz data/dbf900.ebc.gz queries/schema.sql queries/load_emissions.sql queries/load_ogim.sql queries/load_p4.sql queries/load_p5.sql queries/load_wellbore.sql scripts/create_p4_db.py scripts/parse_p4.py scripts/create_p5_db.py scripts/parse_p5.py scripts/create_wellbore_db.py scripts/parse_wellbore.py
	@echo "Building database from OGIM v2.7 + Texas RRC data..."
	@echo "1/7 Creating schema..."
	@duckdb $@ < queries/schema.sql
	@echo "2/7 Loading plumes from Carbon Mapper..."
	@duckdb $@ < queries/load_emissions.sql
	@echo "3/7 Loading infrastructure from OGIM (wells, compressors, processing, tanks)..."
	@duckdb $@ < queries/load_ogim.sql
	@echo "4/7 Parsing and loading Texas RRC P-4 data (purchaser/gatherer info)..."
	@uv run scripts/create_p4_db.py
	@duckdb $@ < queries/load_p4.sql
	@echo "5/7 Parsing and loading Texas RRC P-5 data (organization names)..."
	@uv run scripts/create_p5_db.py
	@duckdb $@ < queries/load_p5.sql
	@echo "6/7 Parsing and loading Texas RRC wellbore data (API→lease mappings)..."
	@uv run scripts/create_wellbore_db.py
	@duckdb $@ < queries/load_wellbore.sql
	@echo "Creating spatial indexes for performance..."
	@duckdb $@ -c "INSTALL spatial; LOAD spatial; CREATE INDEX IF NOT EXISTS idx_wellbore_location_geom ON wellbore.location USING RTREE (geom); CREATE INDEX IF NOT EXISTS idx_emissions_sources_geom ON emissions.sources USING RTREE (geom); CREATE INDEX IF NOT EXISTS idx_p4_gpn_lease ON p4.gpn (oil_gas_code, district, lease_rrcid); CREATE INDEX IF NOT EXISTS idx_p4_gpn_number ON p4.gpn (gpn_number);"
	@echo "7/7 Creating hybrid attribution (Texas RRC + OGIM)..."
	@duckdb $@ < queries/create_attribution.sql
	@echo "✓ Database build complete"

# Regenerate attribution table (without rebuilding entire database)
.PHONY: attribution
attribution: data/data.duckdb
	@echo "Regenerating attribution table..."
	@duckdb data/data.duckdb < queries/create_attribution.sql
	@echo "✓ Attribution complete"

# Generate LNG attribution report
.PHONY: lng-attribution
lng-attribution: data/data.duckdb
	@mkdir -p output
	@echo "Generating LNG attribution report..."
	@duckdb --csv data/data.duckdb < queries/generate_output.sql > output/lng_attribution.csv
	@echo "✓ Report saved to output/lng_attribution.csv"

# Legacy file-based target (for backwards compatibility with 'make all')
output/lng_attribution.csv: data/data.duckdb data/supply-contracts-gemini-2-5-pro.csv
	@$(MAKE) lng-attribution

clean-output:
	rm -f output/lng_attribution.csv

clean:
	rm -f data/data.duckdb output/lng_attribution.csv
	rm -f /tmp/root.csv /tmp/info.csv /tmp/gpn.csv /tmp/lease_name.csv
	rm -f /tmp/p5_org.csv /tmp/p5_specialty.csv /tmp/p5_officer.csv /tmp/p5_activity.csv
	rm -f /tmp/wellbore_root.csv /tmp/wellbore_location.csv /tmp/wellbore_wellid.csv

clean-all: clean
	rm -f data/OGIM_v2.7.gpkg data/plumes_2025-01-01_2025-10-01.zip data/plumes_2025-01-01_2025-10-01.csv
	@echo "Note: RRC data files (data/*.ebc.gz) not removed - download them manually from https://mft.rrc.texas.gov/"
