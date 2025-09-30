.PHONY: all clean csvs db

all: data.duckdb

# Generate CSV files from EBCDIC data
csvs: root.csv info.csv gpn.csv lease_name.csv

root.csv info.csv gpn.csv lease_name.csv: data/p4f606.ebc.gz create_db.py parse_p4.py
	uv run create_db.py

# Create DuckDB database from CSVs
data.duckdb: root.csv info.csv gpn.csv lease_name.csv load_db.sql schema.sql
	rm -f data.duckdb
	duckdb data.duckdb < load_db.sql

clean:
	rm -f root.csv info.csv gpn.csv lease_name.csv data.duckdb