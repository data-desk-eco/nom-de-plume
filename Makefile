.PHONY: all clean csvs db

all: data/data.duckdb

# Generate CSV files from EBCDIC data
csvs: data/root.csv data/info.csv data/gpn.csv data/lease_name.csv

data/root.csv data/info.csv data/gpn.csv data/lease_name.csv: data/p4f606.ebc.gz scripts/create_db.py scripts/parse_p4.py
	uv run scripts/create_db.py

# Create DuckDB database from CSVs
data/data.duckdb: data/root.csv data/info.csv data/gpn.csv data/lease_name.csv queries/load_db.sql queries/schema.sql
	rm -f data/data.duckdb
	duckdb data/data.duckdb < queries/load_db.sql

clean:
	rm -f data/root.csv data/info.csv data/gpn.csv data/lease_name.csv data/data.duckdb