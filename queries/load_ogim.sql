-- Load OGIM infrastructure data into DuckDB
-- Creates unified infrastructure table with geometry and type weighting

INSTALL sqlite;
LOAD sqlite;
INSTALL spatial;
LOAD spatial;

-- Drop existing schema if it exists
DROP SCHEMA IF EXISTS infra CASCADE;
CREATE SCHEMA infra;

-- Create unified infrastructure table combining all facility types
-- Each type gets a weight reflecting its emission likelihood
CREATE OR REPLACE TABLE infra.all_facilities AS
WITH
-- Wells
-- Filter to exclude proposed/permitted wells that haven't been drilled yet
-- This prevents attribution to drilling permits rather than actual infrastructure
wells AS (
    SELECT
        CAST(FAC_ID AS VARCHAR) as facility_id,
        'well' as infra_type,
        OPERATOR as operator,
        FAC_TYPE as facility_subtype,
        FAC_STATUS as status,
        OGIM_STATUS as ogim_status,
        LATITUDE as latitude,
        LONGITUDE as longitude,
        ST_Point(LONGITUDE, LATITUDE) as geom
    FROM sqlite_scan('data/OGIM_v2.7.gpkg', 'Oil_and_Natural_Gas_Wells')
    WHERE LATITUDE IS NOT NULL
        AND LONGITUDE IS NOT NULL
        AND OPERATOR IS NOT NULL
        AND OPERATOR != 'N/A'
        -- Exclude proposed/permitted wells that haven't been built
        AND (FAC_STATUS NOT IN ('PERMITTED', 'PROPOSED') OR FAC_STATUS IS NULL OR FAC_STATUS = 'N/A')
        AND (OGIM_STATUS NOT IN ('PERMITTED', 'PROPOSED') OR OGIM_STATUS IS NULL OR OGIM_STATUS = 'N/A')
),

-- Gas processing plants
processing AS (
    SELECT
        CAST(OGIM_ID AS VARCHAR) as facility_id,
        'processing' as infra_type,
        OPERATOR as operator,
        FAC_TYPE as facility_subtype,
        FAC_STATUS as status,
        OGIM_STATUS as ogim_status,
        LATITUDE as latitude,
        LONGITUDE as longitude,
        ST_Point(LONGITUDE, LATITUDE) as geom
    FROM sqlite_scan('data/OGIM_v2.7.gpkg', 'Gathering_and_Processing')
    WHERE LATITUDE IS NOT NULL
        AND LONGITUDE IS NOT NULL
        AND OPERATOR IS NOT NULL
        AND OPERATOR != 'N/A'
),

-- Compressor stations
compressors AS (
    SELECT
        CAST(OGIM_ID AS VARCHAR) as facility_id,
        'compressor' as infra_type,
        OPERATOR as operator,
        FAC_TYPE as facility_subtype,
        FAC_STATUS as status,
        OGIM_STATUS as ogim_status,
        LATITUDE as latitude,
        LONGITUDE as longitude,
        ST_Point(LONGITUDE, LATITUDE) as geom
    FROM sqlite_scan('data/OGIM_v2.7.gpkg', 'Natural_Gas_Compressor_Stations')
    WHERE LATITUDE IS NOT NULL
        AND LONGITUDE IS NOT NULL
        AND OPERATOR IS NOT NULL
        AND OPERATOR != 'N/A'
        AND (FAC_STATUS = 'IN SERVICE' OR FAC_STATUS = 'N/A' OR FAC_STATUS IS NULL)
        AND (OGIM_STATUS = 'OPERATIONAL' OR OGIM_STATUS = 'N/A' OR OGIM_STATUS IS NULL)
),

-- Tank batteries
tanks AS (
    SELECT
        CAST(OGIM_ID AS VARCHAR) as facility_id,
        'tank_battery' as infra_type,
        OPERATOR as operator,
        FAC_TYPE as facility_subtype,
        FAC_STATUS as status,
        OGIM_STATUS as ogim_status,
        LATITUDE as latitude,
        LONGITUDE as longitude,
        ST_Point(LONGITUDE, LATITUDE) as geom
    FROM sqlite_scan('data/OGIM_v2.7.gpkg', 'Tank_Battery')
    WHERE LATITUDE IS NOT NULL
        AND LONGITUDE IS NOT NULL
        AND OPERATOR IS NOT NULL
        AND OPERATOR != 'N/A'
),

-- Injection and disposal wells
injection AS (
    SELECT
        CAST(OGIM_ID AS VARCHAR) as facility_id,
        'injection_disposal' as infra_type,
        OPERATOR as operator,
        FAC_TYPE as facility_subtype,
        FAC_STATUS as status,
        OGIM_STATUS as ogim_status,
        LATITUDE as latitude,
        LONGITUDE as longitude,
        ST_Point(LONGITUDE, LATITUDE) as geom
    FROM sqlite_scan('data/OGIM_v2.7.gpkg', 'Injection_and_Disposal')
    WHERE LATITUDE IS NOT NULL
        AND LONGITUDE IS NOT NULL
        AND OPERATOR IS NOT NULL
        AND OPERATOR != 'N/A'
),

-- Petroleum terminals
terminals AS (
    SELECT
        CAST(OGIM_ID AS VARCHAR) as facility_id,
        'petroleum_terminal' as infra_type,
        OPERATOR as operator,
        FAC_TYPE as facility_subtype,
        FAC_STATUS as status,
        OGIM_STATUS as ogim_status,
        LATITUDE as latitude,
        LONGITUDE as longitude,
        ST_Point(LONGITUDE, LATITUDE) as geom
    FROM sqlite_scan('data/OGIM_v2.7.gpkg', 'Petroleum_Terminals')
    WHERE LATITUDE IS NOT NULL
        AND LONGITUDE IS NOT NULL
        AND OPERATOR IS NOT NULL
        AND OPERATOR != 'N/A'
),

-- Other stations
stations_other AS (
    SELECT
        CAST(OGIM_ID AS VARCHAR) as facility_id,
        'station_other' as infra_type,
        OPERATOR as operator,
        FAC_TYPE as facility_subtype,
        FAC_STATUS as status,
        OGIM_STATUS as ogim_status,
        LATITUDE as latitude,
        LONGITUDE as longitude,
        ST_Point(LONGITUDE, LATITUDE) as geom
    FROM sqlite_scan('data/OGIM_v2.7.gpkg', 'Stations_Other')
    WHERE LATITUDE IS NOT NULL
        AND LONGITUDE IS NOT NULL
        AND OPERATOR IS NOT NULL
        AND OPERATOR != 'N/A'
),

-- LNG facilities
lng_facilities AS (
    SELECT
        CAST(OGIM_ID AS VARCHAR) as facility_id,
        'lng_facility' as infra_type,
        OPERATOR as operator,
        FAC_TYPE as facility_subtype,
        FAC_STATUS as status,
        OGIM_STATUS as ogim_status,
        LATITUDE as latitude,
        LONGITUDE as longitude,
        ST_Point(LONGITUDE, LATITUDE) as geom
    FROM sqlite_scan('data/OGIM_v2.7.gpkg', 'LNG_Facilities')
    WHERE LATITUDE IS NOT NULL
        AND LONGITUDE IS NOT NULL
        AND OPERATOR IS NOT NULL
        AND OPERATOR != 'N/A'
),

-- Crude oil refineries
refineries AS (
    SELECT
        CAST(OGIM_ID AS VARCHAR) as facility_id,
        'refinery' as infra_type,
        OPERATOR as operator,
        FAC_TYPE as facility_subtype,
        FAC_STATUS as status,
        OGIM_STATUS as ogim_status,
        LATITUDE as latitude,
        LONGITUDE as longitude,
        ST_Point(LONGITUDE, LATITUDE) as geom
    FROM sqlite_scan('data/OGIM_v2.7.gpkg', 'Crude_Oil_Refineries')
    WHERE LATITUDE IS NOT NULL
        AND LONGITUDE IS NOT NULL
        AND OPERATOR IS NOT NULL
        AND OPERATOR != 'N/A'
)

SELECT * FROM wells
UNION ALL
SELECT * FROM processing
UNION ALL
SELECT * FROM compressors
UNION ALL
SELECT * FROM tanks
UNION ALL
SELECT * FROM injection
UNION ALL
SELECT * FROM terminals
UNION ALL
SELECT * FROM stations_other
UNION ALL
SELECT * FROM lng_facilities
UNION ALL
SELECT * FROM refineries;

-- Create spatial index for fast queries
CREATE INDEX idx_infrastructure_geom ON infra.all_facilities USING RTREE (geom);
CREATE INDEX idx_infrastructure_operator ON infra.all_facilities (operator);
CREATE INDEX idx_infrastructure_type ON infra.all_facilities (infra_type);

-- Summary statistics
SELECT
    infra_type,
    COUNT(*) as facility_count,
    COUNT(DISTINCT operator) as unique_operators
FROM infra.all_facilities
GROUP BY infra_type
ORDER BY facility_count DESC;
