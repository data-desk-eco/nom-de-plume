.PHONY: all clean clean-all

all: output/lng_attribution.csv

# Download OGIM v2.7 database from Zenodo (2.9 GB)
data/OGIM_v2.7.gpkg:
	@mkdir -p $(@D)
	@echo "Downloading OGIM v2.7 database from Zenodo (2.9 GB)..."
	@curl -sL -o $@ https://zenodo.org/records/15103476/files/OGIM_v2.7.gpkg
	@echo "✓ OGIM database downloaded"

# Fetch emissions data from Carbon Mapper API (2025 CH4 plumes, Texas + Louisiana)
# Bbox: west, south, east, north covering TX + LA
data/sources.json:
	@mkdir -p $(@D)
	@echo "Fetching emissions data from Carbon Mapper API..."
	@curl -sG -o $@ "https://api.carbonmapper.org/api/v1/catalog/sources.geojson" \
		--data-urlencode "bbox=-106.65" \
		--data-urlencode "bbox=25.84" \
		--data-urlencode "bbox=-88.75" \
		--data-urlencode "bbox=36.50" \
		--data-urlencode "datetime=2025-01-01T00:00:00Z/.." \
		--data-urlencode "plume_gas=CH4"
	@echo "✓ Emissions data fetched"

# Texas RRC data files (p4f606.ebc.gz, orf850.ebc.gz, dbf900.ebc.gz)
# must be downloaded manually from https://mft.rrc.texas.gov/ and placed in data/
# The download links require active browser sessions and cannot be automated

# Parse P-4 data to extract root, info, GPN, and lease name records
# Output goes to /tmp to avoid cluttering the repository
.PHONY: parse-p4
parse-p4: data/p4f606.ebc.gz scripts/create_p4_db.py scripts/parse_p4.py
	@echo "Parsing P-4 data for purchaser/gatherer information..."
	uv run scripts/create_p4_db.py
	@echo "✓ P-4 data parsed to /tmp"

# Parse P-5 data to extract organization names
.PHONY: parse-p5
parse-p5: data/orf850.ebc.gz scripts/create_p5_db.py scripts/parse_p5.py
	@echo "Parsing P-5 data for organization names..."
	uv run scripts/create_p5_db.py
	@echo "✓ P-5 data parsed to /tmp"

# Parse wellbore data to extract API→lease mappings
.PHONY: parse-wellbore
parse-wellbore: data/dbf900.ebc.gz scripts/create_wellbore_db.py scripts/parse_wellbore.py
	@echo "Parsing wellbore data for API number mappings..."
	uv run scripts/create_wellbore_db.py
	@echo "✓ Wellbore data parsed to /tmp"

# Create DuckDB database from OGIM GeoPackage and Carbon Mapper emissions
data/data.duckdb: data/OGIM_v2.7.gpkg data/sources.json data/p4f606.ebc.gz data/orf850.ebc.gz data/dbf900.ebc.gz queries/schema.sql queries/load_emissions.sql queries/load_ogim.sql queries/load_p4.sql queries/load_p5.sql queries/load_wellbore.sql queries/create_ogim_attribution.sql scripts/create_p4_db.py scripts/parse_p4.py scripts/create_p5_db.py scripts/parse_p5.py scripts/create_wellbore_db.py scripts/parse_wellbore.py
	@echo "Building database from OGIM v2.7 data..."
	@echo "1/7 Creating schema..."
	@duckdb $@ < queries/schema.sql
	@echo "2/7 Loading emissions from Carbon Mapper..."
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
	@echo "7/7 Creating attribution table with multi-infrastructure scoring..."
	@duckdb $@ < queries/create_ogim_attribution.sql
	@echo "✓ Database build complete"

# Generate LNG feedgas supply attribution report
output/lng_attribution.csv: data/data.duckdb data/supply-contracts-gemini-2-5-pro.csv queries/ogim_lng_attribution.sql
	@mkdir -p $(@D)
	@echo "Generating LNG attribution report..."
	duckdb --csv data/data.duckdb < queries/ogim_lng_attribution.sql > $@
	@echo "✓ Report saved to $@"

clean:
	rm -f data/data.duckdb output/lng_attribution.csv
	rm -f /tmp/root.csv /tmp/info.csv /tmp/gpn.csv /tmp/lease_name.csv
	rm -f /tmp/p5_org.csv /tmp/p5_specialty.csv /tmp/p5_officer.csv /tmp/p5_activity.csv
	rm -f /tmp/wellbore_root.csv /tmp/wellbore_location.csv /tmp/wellbore_wellid.csv

clean-all: clean
	rm -f data/OGIM_v2.7.gpkg data/sources.json
	@echo "Note: RRC data files (data/*.ebc.gz) not removed - download them manually from https://mft.rrc.texas.gov/"
