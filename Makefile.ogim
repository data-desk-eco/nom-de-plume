.PHONY: all clean lng-attribution test

all: data/data.duckdb

# Create DuckDB database from OGIM GeoPackage and Carbon Mapper emissions
data/data.duckdb: data/OGIM_v2.7.gpkg data/sources_*.json queries/schema.sql queries/load_emissions.sql queries/load_ogim.sql queries/create_ogim_attribution.sql
	@echo "Building database from OGIM v2.7 data..."
	rm -f data/data.duckdb
	@echo "1/4 Creating schema..."
	duckdb data/data.duckdb < queries/schema.sql
	@echo "2/4 Loading emissions from Carbon Mapper..."
	duckdb data/data.duckdb < queries/load_emissions.sql
	@echo "3/4 Loading infrastructure from OGIM (wells, compressors, processing, tanks)..."
	duckdb data/data.duckdb < queries/load_ogim.sql
	@echo "4/4 Creating attribution table with multi-infrastructure scoring..."
	duckdb data/data.duckdb < queries/create_ogim_attribution.sql
	@echo "✓ Database build complete"

# Generate LNG feedgas supply attribution report
lng-attribution: output/lng_attribution.csv

output/lng_attribution.csv: data/data.duckdb data/supply-contracts-gemini-2-5-pro.csv queries/ogim_lng_attribution.sql
	@mkdir -p output
	@echo "Generating LNG attribution report..."
	duckdb --csv data/data.duckdb < queries/ogim_lng_attribution.sql > output/lng_attribution.csv
	@echo "✓ Report saved to output/lng_attribution.csv"

# Test infrastructure loading (shows facility counts by type)
test: data/OGIM_v2.7.gpkg
	@echo "Testing OGIM data loading..."
	duckdb -c "INSTALL sqlite; LOAD sqlite; SELECT 'Wells' as type, COUNT(*) as count FROM sqlite_scan('data/OGIM_v2.7.gpkg', 'Oil_and_Natural_Gas_Wells') WHERE STATE_PROV = 'TEXAS' UNION ALL SELECT 'Compressor Stations', COUNT(*) FROM sqlite_scan('data/OGIM_v2.7.gpkg', 'Natural_Gas_Compressor_Stations') WHERE STATE_PROV = 'TEXAS' UNION ALL SELECT 'Processing', COUNT(*) FROM sqlite_scan('data/OGIM_v2.7.gpkg', 'Gathering_and_Processing') WHERE STATE_PROV = 'TEXAS' UNION ALL SELECT 'Tank Battery', COUNT(*) FROM sqlite_scan('data/OGIM_v2.7.gpkg', 'Tank_Battery') WHERE STATE_PROV = 'TEXAS';"

clean:
	rm -f data/data.duckdb output/lng_attribution.csv
