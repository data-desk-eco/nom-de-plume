-- Load plumes data from Carbon Mapper CSV

-- Load spatial extension (if not already loaded)
LOAD spatial;

-- Load CSV directly into emissions.sources table
INSERT INTO emissions.sources
SELECT
    plume_id as id,
    ST_Point(plume_longitude, plume_latitude) as geom,
    plume_latitude as latitude,
    plume_longitude as longitude,
    gas,
    ipcc_sector,
    TRY_CAST(datetime AS TIMESTAMP) as datetime,
    instrument,
    platform,
    provider,
    mission_phase,
    emission_auto,
    emission_uncertainty_auto,
    emission_cmf_type,
    wind_speed_avg_auto,
    wind_speed_std_auto,
    wind_direction_avg_auto,
    wind_direction_std_auto,
    wind_source_auto,
    plume_bounds,
    gsd,
    sensitivity_mode,
    off_nadir,
    TRY_CAST(published_at AS TIMESTAMP) as published_at,
    TRY_CAST(modified AS TIMESTAMP) as modified,
    emission_version,
    processing_software
FROM read_csv_auto('data/plumes_2025-01-01_2025-10-01.csv', header=true);

-- Show summary
SELECT 'Total plumes' as metric, COUNT(*) as count FROM emissions.sources
UNION ALL
SELECT 'CH4 plumes', COUNT(*) FROM emissions.sources WHERE gas = 'CH4'
UNION ALL
SELECT 'CO2 plumes', COUNT(*) FROM emissions.sources WHERE gas = 'CO2'
UNION ALL
SELECT 'Oil & Gas sector (1B2)', COUNT(*) FROM emissions.sources WHERE ipcc_sector LIKE 'Oil & Gas%'
UNION ALL
SELECT 'Solid Waste sector (6A)', COUNT(*) FROM emissions.sources WHERE ipcc_sector LIKE 'Solid Waste%'
UNION ALL
SELECT 'Plumes in Texas', COUNT(*) FROM emissions.sources
WHERE ST_Within(geom, ST_GeomFromText('POLYGON((-106.65 25.84, -93.51 25.84, -93.51 36.5, -106.65 36.5, -106.65 25.84))'))
UNION ALL
SELECT 'Plumes in Louisiana', COUNT(*) FROM emissions.sources
WHERE ST_Within(geom, ST_GeomFromText('POLYGON((-94.04 28.93, -88.75 28.93, -88.75 33.02, -94.04 33.02, -94.04 28.93))'));
