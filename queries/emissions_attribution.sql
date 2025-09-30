INSTALL spatial;
LOAD spatial;

-- Match all emissions sources to nearest well within 0.5km
-- Shows total wells in radius and operator-specific well count
WITH all_wells AS (
    SELECT
        loc.geom,
        loc.api_county,
        loc.api_unique,
        org.organization_name,
        p4.operator_number
    FROM wellbore.location loc
    JOIN wellbore.wellid wb ON loc.api_county = wb.api_county
                            AND loc.api_unique = wb.api_unique
    JOIN p4.root p4 ON wb.oil_gas_code = p4.oil_gas_code
                    AND wb.district = p4.district
                    AND (wb.lease_number = p4.lease_rrcid OR wb.gas_rrcid = p4.lease_rrcid)
    LEFT JOIN p5.org org ON p4.operator_number = org.operator_number
    WHERE loc.geom IS NOT NULL
),
plume_well_distances AS (
    SELECT
        e.id,
        e.emission_auto,
        e.plume_count,
        e.timestamp_min,
        e.timestamp_max,
        e.geom as plume_geom,
        w.api_county || '-' || w.api_unique as well_api,
        w.organization_name,
        w.operator_number,
        ST_Distance(e.geom, w.geom) * 111 as distance_km,
        ROW_NUMBER() OVER (PARTITION BY e.id ORDER BY ST_Distance(e.geom, w.geom)) as rn
    FROM emissions.sources e
    JOIN all_wells w ON ST_Distance(e.geom, w.geom) < 0.005
    WHERE e.gas = 'CH4'
),
total_well_counts AS (
    SELECT
        e.id,
        COUNT(DISTINCT w.api_county || '-' || w.api_unique) as total_wells_within_radius
    FROM emissions.sources e
    JOIN all_wells w ON ST_Distance(e.geom, w.geom) < 0.005
    WHERE e.gas = 'CH4'
    GROUP BY e.id
),
operator_well_counts AS (
    SELECT
        e.id,
        w.operator_number,
        COUNT(DISTINCT w.api_county || '-' || w.api_unique) as operator_well_count
    FROM emissions.sources e
    JOIN all_wells w ON ST_Distance(e.geom, w.geom) < 0.005
    WHERE e.gas = 'CH4'
    GROUP BY e.id, w.operator_number
)
SELECT
    pwd.id,
    pwd.emission_auto as kg_per_hr,
    pwd.plume_count,
    pwd.timestamp_min,
    pwd.timestamp_max,
    ROUND(ST_Y(pwd.plume_geom), 5) as latitude,
    ROUND(ST_X(pwd.plume_geom), 5) as longitude,
    pwd.well_api as nearest_well_api,
    pwd.organization_name as nearest_well_operator,
    ROUND(pwd.distance_km, 2) as distance_to_nearest_well_km,
    twc.total_wells_within_radius as total_wells_within_500m,
    owc.operator_well_count as operator_wells_within_500m
FROM plume_well_distances pwd
LEFT JOIN total_well_counts twc ON pwd.id = twc.id
LEFT JOIN operator_well_counts owc ON pwd.id = owc.id
                                   AND pwd.operator_number = owc.operator_number
WHERE pwd.rn = 1
ORDER BY pwd.emission_auto DESC NULLS LAST;
