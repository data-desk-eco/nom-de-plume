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

# Download Texas RRC P-4 Production Data (194 MB)
# Contains lease/purchaser/gatherer information
data/p4f606.ebc.gz:
	@mkdir -p $(@D)
	@echo "Downloading Texas RRC P-4 production data (194 MB)..."
	@curl -sL 'https://mft.rrc.texas.gov/link/godrivedownload' \
		-H 'Referer: https://mft.rrc.texas.gov/link/19f9b9c7-2b82-4d7c-8dbd-77145a86d3de' \
		-b 'JSESSIONID=765CDF16A742E1EC2271A85765F66E89; oam.Flash.RENDERMAP.TOKEN=8e4vusz1t' \
		-o $@
	@echo "✓ P-4 data downloaded"

# Download Texas RRC P-5 Organization Data (20 MB)
# Contains operator/purchaser/gatherer names
data/orf850.ebc.gz:
	@mkdir -p $(@D)
	@echo "Downloading Texas RRC P-5 organization data (20 MB)..."
	@curl -sL 'https://mft.rrc.texas.gov/link/godrivedownload' \
		-H 'Referer: https://mft.rrc.texas.gov/link/04652169-eed6-4396-9019-2e270e790f6c' \
		-b 'JSESSIONID=765CDF16A742E1EC2271A85765F66E89; oam.Flash.RENDERMAP.TOKEN=8e4vusz22' \
		-o $@
	@echo "✓ P-5 data downloaded"

# Download Texas RRC Well Bore Database (464 MB)
# Contains API number to RRC lease ID mappings
data/dbf900.ebc.gz:
	@mkdir -p $(@D)
	@echo "Downloading Texas RRC wellbore database (464 MB)..."
	@curl -sL 'https://mft.rrc.texas.gov/link/godrivedownload' \
		-H 'Referer: https://mft.rrc.texas.gov/link/b070ce28-5c58-4fe2-9eb7-8b70befb7af9' \
		-b 'JSESSIONID=765CDF16A742E1EC2271A85765F66E89; oam.Flash.RENDERMAP.TOKEN=8e4vusz2g' \
		-o $@
	@echo "✓ Wellbore data downloaded"

# Parse P-4 data to extract root and GPN (gatherer/purchaser/nominator) records
data/p4_root.csv data/gpn.csv: data/p4f606.ebc.gz scripts/create_p4_db.py scripts/parse_p4.py
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
data/data.duckdb: data/OGIM_v2.7.gpkg data/sources.json data/gpn.csv data/p5_org.csv data/wellbore_wellid.csv queries/schema.sql queries/load_emissions.sql queries/load_ogim.sql queries/load_p4.sql queries/load_p5.sql queries/load_wellbore.sql queries/create_ogim_attribution.sql
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
	rm -f data/data.duckdb output/lng_attribution.csv data/p4_root.csv data/gpn.csv data/p5_org.csv data/wellbore_wellid.csv

clean-all: clean
	rm -f data/OGIM_v2.7.gpkg data/sources.json data/p4f606.ebc.gz data/orf850.ebc.gz data/dbf900.ebc.gz
