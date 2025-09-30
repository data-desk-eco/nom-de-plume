-- Load Well Bore data into DuckDB

-- Install and load spatial extension
INSTALL spatial;
LOAD spatial;

-- Load Well Bore root table
INSERT INTO wellbore.root
SELECT * FROM read_csv_auto('data/wellbore_root.csv');

-- Load Well Bore location table (use all_varchar then cast to handle embedded quotes)
INSERT INTO wellbore.location
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
    -- Create geometry from lat/lon (only for non-zero coordinates)
    -- Fix longitude sign: Texas longitudes should be negative (western hemisphere)
    CASE
        WHEN CAST(wgs84_latitude AS DOUBLE) != 0 AND CAST(wgs84_longitude AS DOUBLE) != 0
        THEN ST_Point(-ABS(CAST(wgs84_longitude AS DOUBLE)), CAST(wgs84_latitude AS DOUBLE))
        ELSE NULL
    END as geom,
    CAST(plane_zone AS INTEGER) as plane_zone,
    CAST(plane_coordinate_east AS DOUBLE) as plane_coordinate_east,
    CAST(plane_coordinate_north AS DOUBLE) as plane_coordinate_north,
    verification_flag
FROM read_csv('data/wellbore_location.csv',
    header=true,
    all_varchar=true,
    ignore_errors=true);

-- Load Well Bore Well-ID table (links API to RRC lease IDs)
INSERT INTO wellbore.wellid
SELECT * FROM read_csv_auto('data/wellbore_wellid.csv');

-- Show summary
SELECT 'Well bores' as metric, COUNT(*) as count FROM wellbore.root
UNION ALL
SELECT 'Well bores with location data', COUNT(*) FROM wellbore.location
UNION ALL
SELECT 'Well bores with geometry', COUNT(*) FROM wellbore.location WHERE geom IS NOT NULL
UNION ALL
SELECT 'Well bores with RRC lease linkage', COUNT(*) FROM wellbore.wellid;
