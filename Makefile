.PHONY: all clean csvs db

all: data/data.duckdb

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
data/data.duckdb: data/root.csv data/info.csv data/gpn.csv data/lease_name.csv data/wellbore_root.csv data/wellbore_location.csv data/wellbore_wellid.csv data/p5_org.csv data/p5_specialty.csv data/p5_officer.csv data/p5_activity.csv data/sources_2025-09-30T20_18_37.074Z.json queries/load_db.sql queries/load_wellbore.sql queries/load_p5.sql queries/load_emissions.sql queries/schema.sql
	rm -f data/data.duckdb
	duckdb data/data.duckdb < queries/schema.sql
	duckdb data/data.duckdb < queries/load_db.sql
	duckdb data/data.duckdb < queries/load_wellbore.sql
	duckdb data/data.duckdb < queries/load_p5.sql
	duckdb data/data.duckdb < queries/load_emissions.sql

clean:
	rm -f data/root.csv data/info.csv data/gpn.csv data/lease_name.csv data/wellbore_root.csv data/wellbore_location.csv data/wellbore_wellid.csv data/p5_org.csv data/p5_specialty.csv data/p5_officer.csv data/p5_activity.csv data/data.duckdb