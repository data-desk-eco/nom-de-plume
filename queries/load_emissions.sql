-- Load emissions data from Carbon Mapper GeoJSON

-- Load spatial extension (if not already loaded)
LOAD spatial;

-- Load GeoJSON directly into emissions.sources table using DuckDB's native spatial functions
-- ST_Read automatically parses GeoJSON and provides geom column
INSERT INTO emissions.sources
SELECT
    SPLIT_PART(id, '?', 1) as id,
    geom,
    gas,
    sector,
    plume_count,
    detection_date_count,
    observation_date_count,
    emission_auto,
    emission_uncertainty_auto,
    timestamp_min,
    timestamp_max,
    published_at_min,
    published_at_max,
    persistence,
    source_name
FROM ST_Read('data/sources_2025-10-01T14_21_01.341Z.json');

-- Show summary
SELECT 'Total emission sources' as metric, COUNT(*) as count FROM emissions.sources
UNION ALL
SELECT 'CH4 sources', COUNT(*) FROM emissions.sources WHERE gas = 'CH4'
UNION ALL
SELECT 'CO2 sources', COUNT(*) FROM emissions.sources WHERE gas = 'CO2'
UNION ALL
SELECT 'Oil & Gas sector (6A)', COUNT(*) FROM emissions.sources WHERE sector = '6A'
UNION ALL
SELECT 'Sources in Texas', COUNT(*) FROM emissions.sources
WHERE ST_Within(geom, ST_GeomFromText('POLYGON((-106.65 25.84, -93.51 25.84, -93.51 36.5, -106.65 36.5, -106.65 25.84))'));
