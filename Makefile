.PHONY: all clean csvs db

all: p4.duckdb

# Generate CSV files from EBCDIC data
csvs: leases.csv gatherers_purchasers.csv lease_names.csv

leases.csv gatherers_purchasers.csv lease_names.csv: data/p4f606.ebc.gz create_db.py parse_p4.py
	uv run create_db.py

# Create DuckDB database from CSVs
p4.duckdb: leases.csv gatherers_purchasers.csv lease_names.csv load_db.sql
	rm -f p4.duckdb
	duckdb p4.duckdb < load_db.sql

clean:
	rm -f leases.csv gatherers_purchasers.csv lease_names.csv p4.duckdb