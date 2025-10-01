.PHONY: all clean clean-all

all: output/lng_attribution.csv

# Download OGIM v2.7 database from Zenodo (2.9 GB)
data/OGIM_v2.7.gpkg:
	@mkdir -p $(@D)
	@echo "Downloading OGIM v2.7 database from Zenodo (2.9 GB)..."
	@echo "This may take several minutes depending on your connection..."
	curl -L -o $@ https://zenodo.org/records/15103476/files/OGIM_v2.7.gpkg
	@echo "✓ OGIM database downloaded"

# Fetch emissions data from Carbon Mapper API (Texas bbox, 2025 CH4 plumes)
data/sources.json:
	@mkdir -p $(@D)
	@echo "Fetching emissions data from Carbon Mapper API..."
	curl -G -o $@ "https://api.carbonmapper.org/api/v1/catalog/sources.geojson" \
		--data-urlencode "bbox=-106.65" \
		--data-urlencode "bbox=25.84" \
		--data-urlencode "bbox=-93.51" \
		--data-urlencode "bbox=36.50" \
		--data-urlencode "datetime=2025-01-01T00:00:00Z/.." \
		--data-urlencode "plume_gas=CH4"
	@echo "✓ Emissions data fetched"

# Create DuckDB database from OGIM GeoPackage and Carbon Mapper emissions
data/data.duckdb: data/OGIM_v2.7.gpkg data/sources.json queries/schema.sql queries/load_emissions.sql queries/load_ogim.sql queries/create_ogim_attribution.sql
	@echo "Building database from OGIM v2.7 data..."
	@echo "1/4 Creating schema..."
	duckdb $@ < queries/schema.sql
	@echo "2/4 Loading emissions from Carbon Mapper..."
	duckdb $@ < queries/load_emissions.sql
	@echo "3/4 Loading infrastructure from OGIM (wells, compressors, processing, tanks)..."
	duckdb $@ < queries/load_ogim.sql
	@echo "4/4 Creating attribution table with multi-infrastructure scoring..."
	duckdb $@ < queries/create_ogim_attribution.sql
	@echo "✓ Database build complete"

# Generate LNG feedgas supply attribution report
output/lng_attribution.csv: data/data.duckdb data/supply-contracts-gemini-2-5-pro.csv queries/ogim_lng_attribution.sql
	@mkdir -p $(@D)
	@echo "Generating LNG attribution report..."
	duckdb --csv data/data.duckdb < queries/ogim_lng_attribution.sql > $@
	@echo "✓ Report saved to $@"

clean:
	rm -f data/data.duckdb output/lng_attribution.csv

clean-all: clean
	rm -f data/OGIM_v2.7.gpkg data/sources.json
