-- Hybrid attribution: One row per plume-entity match
-- Entity = operator (from OGIM/RRC) or purchaser (from RRC P-4 data)
-- Texas plumes get both operator and purchaser rows
-- Non-Texas plumes only get operator rows (no purchaser data available)

INSTALL spatial;
LOAD spatial;

DROP TABLE IF EXISTS emissions.attributed;

CREATE TABLE emissions.attributed AS
WITH
-- ============================================================================
-- TEXAS ATTRIBUTION (RRC-based with purchaser data)
-- ============================================================================
texas_wells AS (
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

-- Texas plumes (geographic bounds)
texas_plumes AS (
    SELECT id, geom, emission_auto, emission_uncertainty_auto, persistence, plume_count, timestamp_min, timestamp_max
    FROM emissions.sources
    WHERE gas = 'CH4'
      AND ST_X(geom) BETWEEN -106.65 AND -93.51  -- Texas longitude
      AND ST_Y(geom) BETWEEN 25.84 AND 36.50     -- Texas latitude
),

-- Spatial join: Texas plumes to RRC wells within 750m
texas_plume_well_pairs AS (
    SELECT
        e.id,
        e.emission_auto,
        e.emission_uncertainty_auto,
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
    FROM texas_plumes e
    CROSS JOIN texas_wells w
    WHERE ST_X(w.geom) BETWEEN ST_X(e.geom) - 0.0075 AND ST_X(e.geom) + 0.0075
      AND ST_Y(w.geom) BETWEEN ST_Y(e.geom) - 0.0075 AND ST_Y(e.geom) + 0.0075
      AND ST_DWithin(e.geom, w.geom, 0.0075)  -- ~750m
),

-- Nearest well per Texas plume
texas_nearest_wells AS (
    SELECT DISTINCT ON (id)
        id,
        emission_auto,
        emission_uncertainty_auto,
        persistence,
        plume_count,
        timestamp_min,
        timestamp_max,
        plume_geom,
        well_api,
        operator_name,
        operator_number,
        oil_gas_code,
        district,
        lease_rrcid,
        field_number,
        distance_km
    FROM texas_plume_well_pairs
    ORDER BY id, distance_km
),

-- Total well counts for Texas plumes
texas_well_counts AS (
    SELECT
        id,
        COUNT(DISTINCT well_api) as total_wells_within_750m
    FROM texas_plume_well_pairs
    GROUP BY id
),

-- Operator well counts for Texas plumes
texas_operator_counts AS (
    SELECT
        id,
        operator_number,
        COUNT(DISTINCT well_api) as operator_wells
    FROM texas_plume_well_pairs
    GROUP BY id, operator_number
),

-- Texas operator attribution (one row per plume)
texas_operator_rows AS (
    SELECT
        nw.id,
        nw.emission_auto as rate_avg_kg_hr,
        ROUND(nw.emission_auto / NULLIF(nw.persistence, 0), 2) as rate_detected_kg_hr,
        nw.emission_uncertainty_auto as rate_uncertainty_kg_hr,
        nw.plume_count,
        nw.timestamp_min,
        nw.timestamp_max,
        ST_Y(nw.plume_geom) as latitude,
        ST_X(nw.plume_geom) as longitude,
        nw.well_api as nearest_facility_id,
        'well' as nearest_facility_type,
        NULL as facility_subtype,
        'operator' as entity_type,
        nw.operator_name as entity_name,
        nw.operator_number as entity_id,
        nw.distance_km as distance_to_nearest_facility_km,
        wc.total_wells_within_750m as total_facilities_within_750m,
        wc.total_wells_within_750m as wells_within_750m,
        0 as compressors_within_750m,
        0 as processing_within_750m,
        0 as tanks_within_750m,
        oc.operator_wells as operator_facilities_of_type,
        ROUND(
            -- Operator Dominance (0-50)
            (oc.operator_wells::FLOAT / NULLIF(wc.total_wells_within_750m, 0)) * 50 +
            -- Distance (0-35)
            GREATEST(0, 35 * (1 - (nw.distance_km / 0.75))) +
            -- Density (5-15)
            CASE
                WHEN wc.total_wells_within_750m = 1 THEN 15
                WHEN wc.total_wells_within_750m <= 3 THEN 12
                WHEN wc.total_wells_within_750m <= 10 THEN 9
                WHEN wc.total_wells_within_750m <= 30 THEN 6
                ELSE 5
            END,
            1
        ) as confidence_score
    FROM texas_nearest_wells nw
    LEFT JOIN texas_well_counts wc ON nw.id = wc.id
    LEFT JOIN texas_operator_counts oc ON nw.id = oc.id AND nw.operator_number = oc.operator_number
),

-- Texas purchaser attribution (one row per plume-purchaser pair)
texas_purchaser_rows AS (
    SELECT
        nw.id,
        nw.emission_auto as rate_avg_kg_hr,
        ROUND(nw.emission_auto / NULLIF(nw.persistence, 0), 2) as rate_detected_kg_hr,
        nw.emission_uncertainty_auto as rate_uncertainty_kg_hr,
        nw.plume_count,
        nw.timestamp_min,
        nw.timestamp_max,
        ST_Y(nw.plume_geom) as latitude,
        ST_X(nw.plume_geom) as longitude,
        nw.well_api as nearest_facility_id,
        'well' as nearest_facility_type,
        NULL as facility_subtype,
        'purchaser' as entity_type,
        gpn_org.organization_name as entity_name,
        gpn.gpn_number as entity_id,
        nw.distance_km as distance_to_nearest_facility_km,
        wc.total_wells_within_750m as total_facilities_within_750m,
        wc.total_wells_within_750m as wells_within_750m,
        0 as compressors_within_750m,
        0 as processing_within_750m,
        0 as tanks_within_750m,
        NULL as operator_facilities_of_type,  -- Not applicable for purchasers
        NULL as confidence_score  -- Purchasers inherit confidence from operator match
    FROM texas_nearest_wells nw
    LEFT JOIN texas_well_counts wc ON nw.id = wc.id
    JOIN p4.gpn gpn ON nw.oil_gas_code = gpn.oil_gas_code
                    AND nw.district = gpn.district
                    AND nw.lease_rrcid = gpn.lease_rrcid
    LEFT JOIN p5.org gpn_org ON gpn.gpn_number = gpn_org.operator_number
    WHERE gpn.type_code = 'H'  -- H = purchaser
      AND gpn.gpn_number IS NOT NULL
),

-- ============================================================================
-- NON-TEXAS ATTRIBUTION (OGIM-based, multi-infrastructure)
-- ============================================================================
non_texas_plumes AS (
    SELECT id, geom, emission_auto, emission_uncertainty_auto, persistence, plume_count, timestamp_min, timestamp_max
    FROM emissions.sources
    WHERE gas = 'CH4'
      AND NOT (ST_X(geom) BETWEEN -106.65 AND -93.51 AND ST_Y(geom) BETWEEN 25.84 AND 36.50)
),

-- Find all OGIM facilities within 750m of non-Texas emissions
non_texas_nearby_facilities AS (
    SELECT
        e.id as emission_id,
        e.geom as emission_geom,
        e.emission_auto,
        e.emission_uncertainty_auto,
        e.persistence,
        e.plume_count,
        e.timestamp_min,
        e.timestamp_max,
        f.facility_id,
        f.infra_type,
        f.operator,
        f.facility_subtype,
        f.geom as facility_geom,
        ST_Distance(e.geom, f.geom) * 111 as distance_km
    FROM non_texas_plumes e
    CROSS JOIN infrastructure.all_facilities f
    WHERE ST_X(f.geom) BETWEEN ST_X(e.geom) - 0.0075 AND ST_X(e.geom) + 0.0075
      AND ST_Y(f.geom) BETWEEN ST_Y(e.geom) - 0.0075 AND ST_Y(e.geom) + 0.0075
      AND ST_DWithin(e.geom, f.geom, 0.0075)
),

-- Total facility counts for non-Texas plumes
non_texas_totals AS (
    SELECT
        emission_id,
        COUNT(*) as total_facilities_within_750m,
        COUNT(*) FILTER (WHERE infra_type = 'well') as wells_within_750m,
        COUNT(*) FILTER (WHERE infra_type = 'compressor') as compressors_within_750m,
        COUNT(*) FILTER (WHERE infra_type = 'processing') as processing_within_750m,
        COUNT(*) FILTER (WHERE infra_type = 'tank_battery') as tanks_within_750m
    FROM non_texas_nearby_facilities
    GROUP BY emission_id
),

-- Operator counts for non-Texas plumes
non_texas_operator_stats AS (
    SELECT
        emission_id,
        infra_type,
        operator,
        COUNT(*) as operator_facilities_of_type
    FROM non_texas_nearby_facilities
    GROUP BY emission_id, infra_type, operator
),

-- Best match for non-Texas plumes (closest facility)
non_texas_best_matches AS (
    SELECT DISTINCT ON (nf.emission_id)
        nf.emission_id,
        nf.emission_auto,
        nf.emission_uncertainty_auto,
        nf.persistence,
        nf.plume_count,
        nf.timestamp_min,
        nf.timestamp_max,
        nf.emission_geom,
        nf.facility_id,
        nf.infra_type,
        nf.operator,
        nf.facility_subtype,
        nf.distance_km,
        totals.total_facilities_within_750m,
        totals.wells_within_750m,
        totals.compressors_within_750m,
        totals.processing_within_750m,
        totals.tanks_within_750m,
        op_stats.operator_facilities_of_type,
        GREATEST(0, 35 * (1 - (nf.distance_km / 0.75))) as distance_score,
        LEAST(50, 50 * (CAST(op_stats.operator_facilities_of_type AS FLOAT) / NULLIF(totals.total_facilities_within_750m, 0))) as operator_dominance_score,
        CASE
            WHEN totals.total_facilities_within_750m = 1 THEN 15
            WHEN totals.total_facilities_within_750m <= 3 THEN 12
            WHEN totals.total_facilities_within_750m <= 10 THEN 9
            WHEN totals.total_facilities_within_750m <= 30 THEN 6
            ELSE 5
        END as density_score
    FROM non_texas_nearby_facilities nf
    INNER JOIN non_texas_totals totals ON nf.emission_id = totals.emission_id
    INNER JOIN non_texas_operator_stats op_stats
        ON nf.emission_id = op_stats.emission_id
        AND nf.operator = op_stats.operator
        AND nf.infra_type = op_stats.infra_type
    ORDER BY nf.emission_id, nf.distance_km ASC
),

-- Non-Texas operator rows (one row per plume, no purchaser data)
non_texas_operator_rows AS (
    SELECT
        bm.emission_id as id,
        bm.emission_auto as rate_avg_kg_hr,
        ROUND(bm.emission_auto / NULLIF(bm.persistence, 0), 2) as rate_detected_kg_hr,
        bm.emission_uncertainty_auto as rate_uncertainty_kg_hr,
        bm.plume_count,
        bm.timestamp_min,
        bm.timestamp_max,
        ST_Y(bm.emission_geom) as latitude,
        ST_X(bm.emission_geom) as longitude,
        bm.facility_id as nearest_facility_id,
        bm.infra_type as nearest_facility_type,
        bm.facility_subtype,
        'operator' as entity_type,
        bm.operator as entity_name,
        NULL as entity_id,  -- OGIM doesn't have numeric IDs
        bm.distance_km as distance_to_nearest_facility_km,
        bm.total_facilities_within_750m,
        bm.wells_within_750m,
        bm.compressors_within_750m,
        bm.processing_within_750m,
        bm.tanks_within_750m,
        bm.operator_facilities_of_type,
        ROUND(
            bm.distance_score + bm.operator_dominance_score + bm.density_score,
            1
        ) as confidence_score
    FROM non_texas_best_matches bm
)

-- Combine all attribution rows (Texas operators + Texas purchasers + Non-Texas operators)
SELECT * FROM texas_operator_rows
UNION ALL
SELECT * FROM texas_purchaser_rows
UNION ALL
SELECT * FROM non_texas_operator_rows;

-- Create indexes
CREATE INDEX idx_attributed_entity_name ON emissions.attributed (entity_name);
CREATE INDEX idx_attributed_entity_type ON emissions.attributed (entity_type);
CREATE INDEX idx_attributed_facility_type ON emissions.attributed (nearest_facility_type);
CREATE INDEX idx_attributed_confidence ON emissions.attributed (confidence_score);

-- Summary statistics
SELECT
    nearest_facility_type,
    COUNT(DISTINCT id) as attributed_plumes,
    ROUND(AVG(confidence_score), 1) as avg_confidence,
    ROUND(AVG(distance_to_nearest_facility_km), 2) as avg_distance_km,
    COUNT(DISTINCT entity_name) FILTER (WHERE entity_type = 'operator') as unique_operators,
    COUNT(*) FILTER (WHERE entity_type = 'purchaser') as plumes_with_purchasers
FROM emissions.attributed
WHERE entity_name IS NOT NULL
GROUP BY nearest_facility_type
ORDER BY attributed_plumes DESC;
