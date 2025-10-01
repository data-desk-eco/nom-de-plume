-- Load P-5 Organization Report data into DuckDB

-- Load Record Type 'A ': Organization information
INSERT INTO p5.org
SELECT * FROM read_csv_auto('/tmp/p5_org.csv');

-- Load Record Type 'F ': Specialty codes
INSERT INTO p5.specialty
SELECT * FROM read_csv_auto('/tmp/p5_specialty.csv');

-- Load Record Type 'K ': Officer information
INSERT INTO p5.officer
SELECT * FROM read_csv_auto('/tmp/p5_officer.csv');

-- Load Record Type 'U ': Activity indicators
INSERT INTO p5.activity
SELECT * FROM read_csv_auto('/tmp/p5_activity.csv');

-- Show summary
SELECT 'Organization records' as metric, COUNT(*) as count FROM p5.org
UNION ALL
SELECT 'Specialty code records', COUNT(*) FROM p5.specialty
UNION ALL
SELECT 'Officer records', COUNT(*) FROM p5.officer
UNION ALL
SELECT 'Activity indicator records', COUNT(*) FROM p5.activity
UNION ALL
SELECT 'Unique organizations', COUNT(DISTINCT operator_number) FROM p5.org
UNION ALL
SELECT 'Active operators', COUNT(*) FROM p5.org WHERE p5_status = 'A'
UNION ALL
SELECT 'Organizations with gatherer codes', COUNT(*) FROM p5.org WHERE gatherer_code != '';
