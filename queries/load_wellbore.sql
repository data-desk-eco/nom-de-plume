-- Load Well Bore data into DuckDB

-- Create wellbore schema
CREATE SCHEMA IF NOT EXISTS wellbore;

-- Load Well Bore root table
CREATE TABLE wellbore.root AS
SELECT * FROM read_csv_auto('data/wellbore_root.csv');

-- Load Well Bore location table (use all_varchar then cast to handle embedded quotes)
CREATE TABLE wellbore.location AS
SELECT
    CAST(api_county AS INTEGER) as api_county,
    CAST(api_unique AS INTEGER) as api_unique,
    CAST(loc_county AS INTEGER) as loc_county,
    abstract,
    survey,
    block_number,
    section,
    alt_section,
    alt_abstract,
    CAST(feet_from_sur_sect_1 AS INTEGER) as feet_from_sur_sect_1,
    direc_from_sur_sect_1,
    CAST(feet_from_sur_sect_2 AS INTEGER) as feet_from_sur_sect_2,
    direc_from_sur_sect_2,
    CAST(wgs84_latitude AS DOUBLE) as wgs84_latitude,
    CAST(wgs84_longitude AS DOUBLE) as wgs84_longitude,
    CAST(plane_zone AS INTEGER) as plane_zone,
    CAST(plane_coordinate_east AS DOUBLE) as plane_coordinate_east,
    CAST(plane_coordinate_north AS DOUBLE) as plane_coordinate_north,
    verification_flag
FROM read_csv('data/wellbore_location.csv',
    header=true,
    all_varchar=true,
    ignore_errors=true);

-- Show summary
SELECT 'Well bores' as metric, COUNT(*) as count FROM wellbore.root
UNION ALL
SELECT 'Well bores with location data', COUNT(*) FROM wellbore.location
UNION ALL
SELECT 'Well bores with coordinates', COUNT(*) FROM wellbore.location
WHERE wgs84_latitude != 0 OR wgs84_longitude != 0;
