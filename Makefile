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
data/root.csv data/info.csv data/gpn.csv data/lease_name.csv: data/p4f606.ebc.gz scripts/create_p4_db.py scripts/parse_p4.py
	@echo "Parsing P-4 data for purchaser/gatherer information..."
	uv run scripts/create_p4_db.py
	@echo "✓ P-4 data parsed"

# Parse P-5 data to extract organization names
data/p5_org.csv: data/orf850.ebc.gz scripts/create_p5_db.py scripts/parse_p5.py
	@echo "Parsing P-5 data for organization names..."
	uv run scripts/create_p5_db.py
	@echo "✓ P-5 data parsed"

# Parse wellbore data to extract API→lease mappings
data/wellbore_wellid.csv: data/dbf900.ebc.gz scripts/create_wellbore_db.py scripts/parse_wellbore.py
	@echo "Parsing wellbore data for API number mappings..."
	uv run scripts/create_wellbore_db.py
	@echo "✓ Wellbore data parsed"

# Create DuckDB database from OGIM GeoPackage and Carbon Mapper emissions
data/data.duckdb: data/OGIM_v2.7.gpkg data/sources.json data/root.csv data/info.csv data/gpn.csv data/lease_name.csv data/p5_org.csv data/wellbore_wellid.csv queries/schema.sql queries/load_emissions.sql queries/load_ogim.sql queries/load_p4.sql queries/load_p5.sql queries/load_wellbore.sql queries/create_ogim_attribution.sql
	@echo "Building database from OGIM v2.7 data..."
	@echo "1/7 Creating schema..."
	duckdb $@ < queries/schema.sql
	@echo "2/7 Loading emissions from Carbon Mapper..."
	duckdb $@ < queries/load_emissions.sql
	@echo "3/7 Loading infrastructure from OGIM (wells, compressors, processing, tanks)..."
	duckdb $@ < queries/load_ogim.sql
	@echo "4/7 Loading Texas RRC P-4 data (purchaser/gatherer info)..."
	duckdb $@ < queries/load_p4.sql
	@echo "5/7 Loading Texas RRC P-5 data (organization names)..."
	duckdb $@ < queries/load_p5.sql
	@echo "6/7 Loading Texas RRC wellbore data (API→lease mappings)..."
	duckdb $@ < queries/load_wellbore.sql
	@echo "7/7 Creating attribution table with multi-infrastructure scoring..."
	duckdb $@ < queries/create_ogim_attribution.sql
	@echo "✓ Database build complete"

# Generate LNG feedgas supply attribution report
output/lng_attribution.csv: data/data.duckdb data/supply-contracts-gemini-2-5-pro.csv queries/ogim_lng_attribution.sql
	@mkdir -p $(@D)
	@echo "Generating LNG attribution report..."
	duckdb --csv data/data.duckdb < queries/ogim_lng_attribution.sql > $@
	@echo "✓ Report saved to $@"

clean:
	rm -f data/data.duckdb output/lng_attribution.csv data/root.csv data/info.csv data/gpn.csv data/lease_name.csv data/p5_org.csv data/wellbore_wellid.csv data/wellbore_root.csv data/wellbore_location.csv data/p5_specialty.csv data/p5_officer.csv data/p5_activity.csv

clean-all: clean
	rm -f data/OGIM_v2.7.gpkg data/sources.json
	@echo "Note: RRC data files (data/*.ebc.gz) not removed - download them manually from https://mft.rrc.texas.gov/"
