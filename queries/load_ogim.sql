-- Load OGIM infrastructure data into DuckDB
-- Creates unified infrastructure table with geometry and type weighting

INSTALL sqlite;
LOAD sqlite;
INSTALL spatial;
LOAD spatial;

-- Drop existing schema if it exists
DROP SCHEMA IF EXISTS infrastructure CASCADE;
CREATE SCHEMA infrastructure;

-- Create unified infrastructure table combining all facility types
-- Each type gets a weight reflecting its emission likelihood
CREATE OR REPLACE TABLE infrastructure.all_facilities AS
WITH
-- Wells (baseline weight = 1.0)
-- Note: Including all wells regardless of status since plugged wells can still emit
wells AS (
    SELECT
        FAC_ID as facility_id,
        'well' as infra_type,
        1.0 as type_weight,
        OPERATOR as operator,
        FAC_TYPE as facility_subtype,
        FAC_STATUS as status,
        OGIM_STATUS as ogim_status,
        LATITUDE as latitude,
        LONGITUDE as longitude,
        ST_Point(LONGITUDE, LATITUDE) as geom
    FROM sqlite_scan('data/OGIM_v2.7.gpkg', 'Oil_and_Natural_Gas_Wells')
    WHERE STATE_PROV IN ('TEXAS', 'LOUISIANA')
        AND LATITUDE IS NOT NULL
        AND LONGITUDE IS NOT NULL
        AND OPERATOR IS NOT NULL
        AND OPERATOR != 'N/A'
),

-- Gas processing plants (highest weight = 2.0)
processing AS (
    SELECT
        CAST(OGIM_ID AS VARCHAR) as facility_id,
        'processing' as infra_type,
        2.0 as type_weight,
        OPERATOR as operator,
        FAC_TYPE as facility_subtype,
        FAC_STATUS as status,
        OGIM_STATUS as ogim_status,
        LATITUDE as latitude,
        LONGITUDE as longitude,
        ST_Point(LONGITUDE, LATITUDE) as geom
    FROM sqlite_scan('data/OGIM_v2.7.gpkg', 'Gathering_and_Processing')
    WHERE STATE_PROV IN ('TEXAS', 'LOUISIANA')
        AND LATITUDE IS NOT NULL
        AND LONGITUDE IS NOT NULL
        AND OPERATOR IS NOT NULL
        AND OPERATOR != 'N/A'
),

-- Compressor stations (high weight = 1.5)
compressors AS (
    SELECT
        CAST(OGIM_ID AS VARCHAR) as facility_id,
        'compressor' as infra_type,
        1.5 as type_weight,
        OPERATOR as operator,
        FAC_TYPE as facility_subtype,
        FAC_STATUS as status,
        OGIM_STATUS as ogim_status,
        LATITUDE as latitude,
        LONGITUDE as longitude,
        ST_Point(LONGITUDE, LATITUDE) as geom
    FROM sqlite_scan('data/OGIM_v2.7.gpkg', 'Natural_Gas_Compressor_Stations')
    WHERE STATE_PROV IN ('TEXAS', 'LOUISIANA')
        AND LATITUDE IS NOT NULL
        AND LONGITUDE IS NOT NULL
        AND OPERATOR IS NOT NULL
        AND OPERATOR != 'N/A'
        AND (FAC_STATUS = 'IN SERVICE' OR FAC_STATUS = 'N/A' OR FAC_STATUS IS NULL)
        AND (OGIM_STATUS = 'OPERATIONAL' OR OGIM_STATUS = 'N/A' OR OGIM_STATUS IS NULL)
),

-- Tank batteries (medium-high weight = 1.3)
tanks AS (
    SELECT
        CAST(OGIM_ID AS VARCHAR) as facility_id,
        'tank_battery' as infra_type,
        1.3 as type_weight,
        OPERATOR as operator,
        FAC_TYPE as facility_subtype,
        FAC_STATUS as status,
        OGIM_STATUS as ogim_status,
        LATITUDE as latitude,
        LONGITUDE as longitude,
        ST_Point(LONGITUDE, LATITUDE) as geom
    FROM sqlite_scan('data/OGIM_v2.7.gpkg', 'Tank_Battery')
    WHERE STATE_PROV IN ('TEXAS', 'LOUISIANA')
        AND LATITUDE IS NOT NULL
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
SELECT * FROM tanks;

-- Create spatial index for fast queries
CREATE INDEX idx_infrastructure_geom ON infrastructure.all_facilities USING RTREE (geom);
CREATE INDEX idx_infrastructure_operator ON infrastructure.all_facilities (operator);
CREATE INDEX idx_infrastructure_type ON infrastructure.all_facilities (infra_type);

-- Summary statistics
SELECT
    infra_type,
    type_weight,
    COUNT(*) as facility_count,
    COUNT(DISTINCT operator) as unique_operators
FROM infrastructure.all_facilities
GROUP BY infra_type, type_weight
ORDER BY type_weight DESC;
