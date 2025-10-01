-- Load P4 data into DuckDB with faithful schema

-- Load Record Type 01: P-4 Root (current schedule state)
INSERT INTO p4.root
SELECT * FROM read_csv_auto('/tmp/root.csv');

-- Load Record Type 02: P-4 Info (temporal P-4 filings)
INSERT INTO p4.info
SELECT * FROM read_csv_auto('/tmp/info.csv');

-- Load Record Type 03: P-4 GPN (gatherer/purchaser/nominator)
INSERT INTO p4.gpn
SELECT * FROM read_csv_auto('/tmp/gpn.csv');

-- Load Record Type 07: P-4 Lease Name
INSERT INTO p4.lease_name
SELECT * FROM read_csv_auto('/tmp/lease_name.csv');

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
