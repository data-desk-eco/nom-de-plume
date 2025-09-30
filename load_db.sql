-- Load P4 data into DuckDB with faithful schema

-- Create p4 schema
CREATE SCHEMA IF NOT EXISTS p4;

-- Load Record Type 01: P-4 Root (current schedule state)
CREATE TABLE p4.root AS
SELECT * FROM read_csv_auto('root.csv');

-- Load Record Type 02: P-4 Info (temporal P-4 filings)
CREATE TABLE p4.info AS
SELECT * FROM read_csv_auto('info.csv');

-- Load Record Type 03: P-4 GPN (gatherer/purchaser/nominator)
CREATE TABLE p4.gpn AS
SELECT * FROM read_csv_auto('gpn.csv');

-- Load Record Type 07: P-4 Lease Name
CREATE TABLE p4.lease_name AS
SELECT * FROM read_csv_auto('lease_name.csv');

-- Show summary
SELECT 'Root records (leases)' as metric, COUNT(*) as count FROM p4.root
UNION ALL
SELECT 'Info records (P-4 filings)', COUNT(*) FROM p4.info
UNION ALL
SELECT 'GPN records (gatherers/purchasers/nominators)', COUNT(*) FROM p4.gpn
UNION ALL
SELECT 'Lease name records', COUNT(*) FROM p4.lease_name
UNION ALL
SELECT 'Unique operators', COUNT(DISTINCT info_operator_number) FROM p4.info
UNION ALL
SELECT 'Unique gatherers/purchasers', COUNT(DISTINCT gpn_number) FROM p4.gpn;
