-- Create materialized attribution table
-- Performs expensive spatial join between emissions and wells
-- Optimized: spatial join done once, then aggregated

INSTALL spatial;
LOAD spatial;

DROP TABLE IF EXISTS emissions.attributed;

CREATE TABLE emissions.attributed AS
WITH all_wells AS (
    SELECT
        loc.geom,
        loc.api_county,
        loc.api_unique,
        op_org.organization_name as operator_name,
        p4.operator_number,
        p4.oil_gas_code,
        p4.district,
        p4.lease_rrcid,
        p4.field_number
    FROM wellbore.location loc
    JOIN wellbore.wellid wb ON loc.api_county = wb.api_county
                            AND loc.api_unique = wb.api_unique
    JOIN p4.root p4 ON wb.oil_gas_code = p4.oil_gas_code
                    AND wb.district = p4.district
                    AND (wb.lease_number = p4.lease_rrcid OR wb.gas_rrcid = p4.lease_rrcid)
    LEFT JOIN p5.org op_org ON p4.operator_number = op_org.operator_number
    WHERE loc.geom IS NOT NULL
),
-- Compute spatial join ONCE and materialize all plume-well pairs within 500m
all_plume_well_pairs AS (
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
        w.field_number,
        ST_Distance(e.geom, w.geom) * 111 as distance_km
    FROM emissions.sources e
    JOIN all_wells w ON
        -- Bounding box pre-filter (uses spatial index)
        ST_Within(w.geom, ST_Buffer(e.geom, 0.005))
        -- Exact distance check
        AND ST_Distance(e.geom, w.geom) < 0.005
    WHERE e.gas = 'CH4'
),
-- Find nearest well for each plume
nearest_wells_with_rank AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY distance_km) as rn
    FROM all_plume_well_pairs
),
nearest_wells_only AS (
    SELECT * FROM nearest_wells_with_rank WHERE rn = 1
),
-- Count total wells within radius (from materialized pairs)
total_well_counts AS (
    SELECT
        id,
        COUNT(DISTINCT well_api) as total_wells_within_radius
    FROM all_plume_well_pairs
    GROUP BY id
),
-- Count wells per operator (from materialized pairs)
operator_well_counts AS (
    SELECT
        id,
        operator_number,
        COUNT(DISTINCT well_api) as operator_well_count
    FROM all_plume_well_pairs
    GROUP BY id, operator_number
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
        ) as purchaser_names
    FROM nearest_wells_only pwd
    JOIN p4.gpn gpn ON pwd.oil_gas_code = gpn.oil_gas_code
                    AND pwd.district = gpn.district
                    AND pwd.lease_rrcid = gpn.lease_rrcid
    LEFT JOIN p5.org gpn_org ON gpn.gpn_number = gpn_org.operator_number
    WHERE gpn.type_code = 'H'
      AND gpn.gpn_number IS NOT NULL
    GROUP BY pwd.id
),
lease_names_at_time AS (
    SELECT
        pwd.id,
        ln.lease_name
    FROM nearest_wells_only pwd
    LEFT JOIN LATERAL (
        SELECT lease_name
        FROM p4.lease_name ln
        WHERE ln.oil_gas_code = pwd.oil_gas_code
          AND ln.district = pwd.district
          AND ln.lease_rrcid = pwd.lease_rrcid
        ORDER BY ln.sequence_date_key DESC
        LIMIT 1
    ) ln ON true
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
    pwd.operator_number,
    pwd.field_number,
    ln.lease_name,
    ROUND(pwd.distance_km, 2) as distance_to_nearest_well_km,
    twc.total_wells_within_radius as total_wells_within_500m,
    owc.operator_well_count as operator_wells_within_500m,
    ROUND(
        -- Operator Dominance (0-50): % of nearby wells belonging to matched operator
        (owc.operator_well_count::FLOAT / NULLIF(twc.total_wells_within_radius, 0)) * 50 +
        -- Distance (0-35): closer wells = higher confidence
        GREATEST(0, 35 - (pwd.distance_km * 70)) +
        -- Well Density (5-15): fewer wells = higher confidence (less ambiguity)
        CASE
            WHEN twc.total_wells_within_radius = 1 THEN 15
            WHEN twc.total_wells_within_radius BETWEEN 2 AND 5 THEN 12
            WHEN twc.total_wells_within_radius BETWEEN 6 AND 10 THEN 8
            ELSE 5
        END,
        1
    ) as confidence_score,
    pi.purchaser_names
FROM nearest_wells_only pwd
LEFT JOIN total_well_counts twc ON pwd.id = twc.id
LEFT JOIN operator_well_counts owc ON pwd.id = owc.id
                                   AND pwd.operator_number = owc.operator_number
LEFT JOIN purchaser_info pi ON pwd.id = pi.id
LEFT JOIN lease_names_at_time ln ON pwd.id = ln.id;
