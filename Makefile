.PHONY: all clean csvs db attribution lng-attribution

all: data/data.duckdb

# Generate emissions attribution report (legacy CSV export)
attribution: output/emissions_attribution.csv

output/emissions_attribution.csv: data/data.duckdb queries/emissions_attribution.sql
	@mkdir -p output
	duckdb --csv data/data.duckdb < queries/emissions_attribution.sql > output/emissions_attribution.csv

# Generate LNG feedgas supply attribution report
lng-attribution: output/lng_attribution.csv

output/lng_attribution.csv: data/data.duckdb data/supply-contracts-gemini-2-5-pro.csv queries/lng_attribution.sql
	@mkdir -p output
	duckdb --csv data/data.duckdb < queries/lng_attribution.sql > output/lng_attribution.csv

# Generate CSV files from EBCDIC data
csvs: data/root.csv data/info.csv data/gpn.csv data/lease_name.csv data/wellbore_root.csv data/wellbore_location.csv data/wellbore_wellid.csv data/p5_org.csv data/p5_specialty.csv data/p5_officer.csv data/p5_activity.csv

# P4 (lease/producer) data
data/root.csv data/info.csv data/gpn.csv data/lease_name.csv: data/p4f606.ebc.gz scripts/create_p4_db.py scripts/parse_p4.py
	uv run scripts/create_p4_db.py

# Well bore data
data/wellbore_root.csv data/wellbore_location.csv data/wellbore_wellid.csv: data/dbf900.ebc.gz scripts/create_wellbore_db.py scripts/parse_wellbore.py
	uv run scripts/create_wellbore_db.py

# P5 (organization) data
data/p5_org.csv data/p5_specialty.csv data/p5_officer.csv data/p5_activity.csv: data/orf850.ebc.gz scripts/create_p5_db.py scripts/parse_p5.py
	uv run scripts/create_p5_db.py

# Create DuckDB database from CSVs and GeoJSON
data/data.duckdb: data/root.csv data/info.csv data/gpn.csv data/lease_name.csv data/wellbore_root.csv data/wellbore_location.csv data/wellbore_wellid.csv data/p5_org.csv data/p5_specialty.csv data/p5_officer.csv data/p5_activity.csv data/sources_2025-09-30T20_18_37.074Z.json queries/load_p4.sql queries/load_wellbore.sql queries/load_p5.sql queries/load_emissions.sql queries/schema.sql queries/create_indexes.sql queries/create_attribution_table.sql
	rm -f data/data.duckdb
	duckdb data/data.duckdb < queries/schema.sql
	duckdb data/data.duckdb < queries/load_p4.sql
	duckdb data/data.duckdb < queries/load_wellbore.sql
	duckdb data/data.duckdb < queries/load_p5.sql
	duckdb data/data.duckdb < queries/load_emissions.sql
	duckdb data/data.duckdb < queries/create_indexes.sql
	duckdb data/data.duckdb < queries/create_attribution_table.sql

clean:
	rm -f data/root.csv data/info.csv data/gpn.csv data/lease_name.csv data/wellbore_root.csv data/wellbore_location.csv data/wellbore_wellid.csv data/p5_org.csv data/p5_specialty.csv data/p5_officer.csv data/p5_activity.csv data/data.duckdb
