INSTALL spatial;
LOAD spatial;

-- Match all CH4 emissions sources to nearest well within 0.5km
-- Shows total wells in radius, operator-specific well count, and purchaser/gatherer info
WITH all_wells AS (
    SELECT
        loc.geom,
        loc.api_county,
        loc.api_unique,
        op_org.organization_name as operator_name,
        p4.operator_number,
        p4.oil_gas_code,
        p4.district,
        p4.lease_rrcid
    FROM wellbore.location loc
    JOIN wellbore.wellid wb ON loc.api_county = wb.api_county
                            AND loc.api_unique = wb.api_unique
    JOIN p4.root p4 ON wb.oil_gas_code = p4.oil_gas_code
                    AND wb.district = p4.district
                    AND (wb.lease_number = p4.lease_rrcid OR wb.gas_rrcid = p4.lease_rrcid)
    LEFT JOIN p5.org op_org ON p4.operator_number = op_org.operator_number
    WHERE loc.geom IS NOT NULL
),
plume_well_distances AS (
    SELECT
        e.id,
        e.emission_auto,
        e.persistence,
        e.plume_count,
        e.timestamp_min,
        e.timestamp_max,
        e.geom as plume_geom,
        w.api_county || '-' || w.api_unique as well_api,
        w.operator_name,
        w.operator_number,
        w.oil_gas_code,
        w.district,
        w.lease_rrcid,
        ST_Distance(e.geom, w.geom) * 111 as distance_km,
        ROW_NUMBER() OVER (PARTITION BY e.id ORDER BY ST_Distance(e.geom, w.geom)) as rn
    FROM emissions.sources e
    JOIN all_wells w ON ST_Distance(e.geom, w.geom) < 0.005
    WHERE e.gas = 'CH4'
),
nearest_wells_only AS (
    SELECT * FROM plume_well_distances WHERE rn = 1
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
),
purchaser_info AS (
    SELECT
        pwd.id,
        STRING_AGG(
            DISTINCT
            CASE
                WHEN gpn_org.organization_name IS NOT NULL
                THEN '[' || gpn.gpn_number || '] ' || gpn_org.organization_name
                ELSE '[' || gpn.gpn_number || ']'
            END,
            '; '
        ) as purchaser_gatherer_names
    FROM nearest_wells_only pwd
    JOIN p4.gpn gpn ON pwd.oil_gas_code = gpn.oil_gas_code
                    AND pwd.district = gpn.district
                    AND pwd.lease_rrcid = gpn.lease_rrcid
    LEFT JOIN p5.org gpn_org ON gpn.gpn_number = gpn_org.operator_number
    WHERE gpn.type_code IN ('G', 'P')  -- Gatherers and Purchasers
      AND gpn.gpn_number IS NOT NULL
    GROUP BY pwd.id
)
SELECT
    pwd.id,
    pwd.emission_auto as rate_avg_kg_hr,
    ROUND(pwd.emission_auto / NULLIF(pwd.persistence, 0), 2) as rate_detected_kg_hr,
    pwd.plume_count,
    pwd.timestamp_min,
    pwd.timestamp_max,
    ROUND(ST_Y(pwd.plume_geom), 5) as latitude,
    ROUND(ST_X(pwd.plume_geom), 5) as longitude,
    pwd.well_api as nearest_well_api,
    pwd.operator_name as nearest_well_operator,
    ROUND(pwd.distance_km, 2) as distance_to_nearest_well_km,
    twc.total_wells_within_radius as total_wells_within_500m,
    owc.operator_well_count as operator_wells_within_500m,
    pi.purchaser_gatherer_names
FROM nearest_wells_only pwd
LEFT JOIN total_well_counts twc ON pwd.id = twc.id
LEFT JOIN operator_well_counts owc ON pwd.id = owc.id
                                   AND pwd.operator_number = owc.operator_number
LEFT JOIN purchaser_info pi ON pwd.id = pi.id
ORDER BY pwd.timestamp_max DESC, rate_detected_kg_hr DESC NULLS LAST;
