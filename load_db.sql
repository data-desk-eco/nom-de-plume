-- Load P4 data into DuckDB

-- Create leases table (deduplicate by keeping last occurrence)
CREATE TABLE leases AS
SELECT DISTINCT ON (oil_gas_code, district, lease_rrcid) *
FROM read_csv_auto('leases.csv')
ORDER BY oil_gas_code, district, lease_rrcid;

-- Create gatherers_purchasers table
CREATE TABLE gatherers_purchasers AS
SELECT * FROM read_csv_auto('gatherers_purchasers.csv');

-- Show summary
SELECT 'Total leases' as metric, COUNT(*) as count FROM leases
UNION ALL
SELECT 'Total gatherer/purchaser records', COUNT(*) FROM gatherers_purchasers
UNION ALL
SELECT 'Unique operators', COUNT(DISTINCT operator_number) FROM leases
UNION ALL
SELECT 'Unique gatherers/purchasers', COUNT(DISTINCT gpn_number) FROM gatherers_purchasers;