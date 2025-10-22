-- Hybrid attribution: One row per plume with operator attribution
-- Wells with RRC P-4 data use RRC operator attribution
-- Wells without P-4 data fall back to OGIM operator data
-- All other infrastructure uses OGIM operator data

INSTALL spatial;
LOAD spatial;

DROP TABLE IF EXISTS emissions.attributed;

CREATE TABLE emissions.attributed AS
WITH
-- ============================================================================
-- TEXAS ATTRIBUTION (RRC-based with purchaser data)
-- ============================================================================
-- Wells that successfully joined to P-4 (have RRC operator data)
texas_wells_with_rrc AS (
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

-- Create a set of API numbers for wells handled by RRC
rrc_handled_wells AS (
    SELECT DISTINCT api_county || '-' || api_unique as well_api
    FROM texas_wells_with_rrc
),

-- All plumes (will be filtered separately for RRC vs OGIM)
all_plumes AS (
    SELECT id, geom, emission_auto, emission_uncertainty_auto, datetime
    FROM emissions.sources
    WHERE gas = 'CH4'
),

-- Spatial join: All plumes to RRC wells within search radius
rrc_plume_well_pairs AS (
    SELECT
        e.id,
        e.emission_auto,
        e.emission_uncertainty_auto,
        e.datetime,
        e.geom as plume_geom,
        w.api_county || '-' || w.api_unique as well_api,
        w.operator_name,
        w.operator_number,
        w.oil_gas_code,
        w.district,
        w.lease_rrcid,
        w.field_number,
        ST_Distance(e.geom, w.geom) * 111 as distance_km
    FROM all_plumes e
    CROSS JOIN texas_wells_with_rrc w
    WHERE ST_X(w.geom) BETWEEN ST_X(e.geom) - 0.015 AND ST_X(e.geom) + 0.015
      AND ST_Y(w.geom) BETWEEN ST_Y(e.geom) - 0.015 AND ST_Y(e.geom) + 0.015
      AND ST_DWithin(e.geom, w.geom, 0.015)  -- ~1.5km
),

-- Nearest RRC well per plume
rrc_nearest_wells AS (
    SELECT DISTINCT ON (id)
        id,
        emission_auto,
        emission_uncertainty_auto,
        datetime,
        plume_geom,
        well_api,
        operator_name,
        operator_number,
        oil_gas_code,
        district,
        lease_rrcid,
        field_number,
        distance_km
    FROM rrc_plume_well_pairs
    ORDER BY id, distance_km
),

-- Total RRC well counts per plume
rrc_well_counts AS (
    SELECT
        id,
        COUNT(DISTINCT well_api) as total_wells_nearby
    FROM rrc_plume_well_pairs
    GROUP BY id
),

-- Operator RRC well counts per plume
rrc_operator_counts AS (
    SELECT
        id,
        operator_number,
        COUNT(DISTINCT well_api) as operator_wells
    FROM rrc_plume_well_pairs
    GROUP BY id, operator_number
),

-- RRC operator attribution (one row per plume)
rrc_operator_rows AS (
    SELECT
        nw.id,
        nw.emission_auto as rate_kg_hr,
        nw.emission_uncertainty_auto as rate_uncertainty_kg_hr,
        nw.datetime,
        ST_Y(nw.plume_geom) as latitude,
        ST_X(nw.plume_geom) as longitude,
        nw.well_api as nearest_facility_id,
        'well' as nearest_facility_type,
        NULL as facility_subtype,
        'operator' as entity_type,
        nw.operator_name as entity_name,
        nw.operator_number as entity_id,
        nw.distance_km as distance_to_nearest_facility_km,
        wc.total_wells_nearby as total_facilities_nearby,
        wc.total_wells_nearby as wells_nearby,
        0 as compressors_nearby,
        0 as processing_nearby,
        0 as tanks_nearby,
        oc.operator_wells as operator_facilities_of_type,
        ROUND(
            -- Operator Dominance (0-50)
            (oc.operator_wells::FLOAT / NULLIF(wc.total_wells_nearby, 0)) * 50 +
            -- Distance (0-35)
            GREATEST(0, 35 * (1 - (nw.distance_km / 1.5))) +
            -- Density (5-15): inverse log scale, fewer facilities = higher score
            LEAST(15, GREATEST(5, 15 - LOG(GREATEST(1, wc.total_wells_nearby)) * 3)),
            1
        ) as confidence_score
    FROM rrc_nearest_wells nw
    LEFT JOIN rrc_well_counts wc ON nw.id = wc.id
    LEFT JOIN rrc_operator_counts oc ON nw.id = oc.id AND nw.operator_number = oc.operator_number
),

-- ============================================================================
-- OGIM ATTRIBUTION (Nationwide, excludes wells already handled by RRC)
-- ============================================================================
-- Find OGIM facilities within search radius of plumes
-- Exclude wells that are already handled by RRC using NOT EXISTS
ogim_nearby_facilities AS (
    SELECT
        e.id as emission_id,
        e.geom as emission_geom,
        e.emission_auto,
        e.emission_uncertainty_auto,
        e.datetime,
        f.facility_id,
        f.infra_type,
        f.operator,
        f.facility_subtype,
        f.geom as facility_geom,
        ST_Distance(e.geom, f.geom) * 111 as distance_km
    FROM all_plumes e
    CROSS JOIN infrastructure.all_facilities f
    WHERE ST_X(f.geom) BETWEEN ST_X(e.geom) - 0.015 AND ST_X(e.geom) + 0.015
      AND ST_Y(f.geom) BETWEEN ST_Y(e.geom) - 0.015 AND ST_Y(e.geom) + 0.015
      AND ST_DWithin(e.geom, f.geom, 0.015)
      -- Exclude wells that are already handled by RRC
      AND NOT (f.infra_type = 'well' AND EXISTS (
          SELECT 1 FROM rrc_handled_wells rrc WHERE rrc.well_api = f.facility_id
      ))
),

-- Total facility counts for all plumes
ogim_totals AS (
    SELECT
        emission_id,
        COUNT(*) as total_facilities_nearby,
        COUNT(*) FILTER (WHERE infra_type = 'well') as wells_nearby,
        COUNT(*) FILTER (WHERE infra_type = 'compressor') as compressors_nearby,
        COUNT(*) FILTER (WHERE infra_type = 'processing') as processing_nearby,
        COUNT(*) FILTER (WHERE infra_type = 'tank_battery') as tanks_nearby,
        COUNT(*) FILTER (WHERE infra_type = 'injection_disposal') as injection_nearby,
        COUNT(*) FILTER (WHERE infra_type = 'petroleum_terminal') as terminals_nearby,
        COUNT(*) FILTER (WHERE infra_type = 'station_other') as stations_nearby,
        COUNT(*) FILTER (WHERE infra_type = 'lng_facility') as lng_nearby,
        COUNT(*) FILTER (WHERE infra_type = 'refinery') as refineries_nearby
    FROM ogim_nearby_facilities
    GROUP BY emission_id
),

-- Operator counts for all plumes
ogim_operator_stats AS (
    SELECT
        emission_id,
        infra_type,
        operator,
        COUNT(*) as operator_facilities_of_type
    FROM ogim_nearby_facilities
    GROUP BY emission_id, infra_type, operator
),

-- Best match for all plumes (closest facility)
ogim_best_matches AS (
    SELECT DISTINCT ON (nf.emission_id)
        nf.emission_id,
        nf.emission_auto,
        nf.emission_uncertainty_auto,
        nf.datetime,
        nf.emission_geom,
        nf.facility_id,
        nf.infra_type,
        nf.operator,
        nf.facility_subtype,
        nf.distance_km,
        totals.total_facilities_nearby,
        totals.wells_nearby,
        totals.compressors_nearby,
        totals.processing_nearby,
        totals.tanks_nearby,
        totals.injection_nearby,
        totals.terminals_nearby,
        totals.stations_nearby,
        totals.lng_nearby,
        totals.refineries_nearby,
        op_stats.operator_facilities_of_type,
        GREATEST(0, 35 * (1 - (nf.distance_km / 1.5))) as distance_score,
        LEAST(50, 50 * (CAST(op_stats.operator_facilities_of_type AS FLOAT) / NULLIF(totals.total_facilities_nearby, 0))) as operator_dominance_score,
        LEAST(15, GREATEST(5, 15 - LOG(GREATEST(1, totals.total_facilities_nearby)) * 3)) as density_score
    FROM ogim_nearby_facilities nf
    INNER JOIN ogim_totals totals ON nf.emission_id = totals.emission_id
    INNER JOIN ogim_operator_stats op_stats
        ON nf.emission_id = op_stats.emission_id
        AND nf.operator = op_stats.operator
        AND nf.infra_type = op_stats.infra_type
    ORDER BY nf.emission_id, nf.distance_km ASC
),

-- OGIM operator rows (one row per plume)
ogim_operator_rows AS (
    SELECT
        bm.emission_id as id,
        bm.emission_auto as rate_kg_hr,
        bm.emission_uncertainty_auto as rate_uncertainty_kg_hr,
        bm.datetime,
        ST_Y(bm.emission_geom) as latitude,
        ST_X(bm.emission_geom) as longitude,
        bm.facility_id as nearest_facility_id,
        bm.infra_type as nearest_facility_type,
        bm.facility_subtype,
        'operator' as entity_type,
        bm.operator as entity_name,
        NULL as entity_id,  -- OGIM doesn't have numeric IDs
        bm.distance_km as distance_to_nearest_facility_km,
        bm.total_facilities_nearby,
        bm.wells_nearby,
        bm.compressors_nearby,
        bm.processing_nearby,
        bm.tanks_nearby,
        bm.operator_facilities_of_type,
        ROUND(
            bm.distance_score + bm.operator_dominance_score + bm.density_score,
            1
        ) as confidence_score
    FROM ogim_best_matches bm
)

-- Combine all attribution rows (RRC wells with P-4 data + OGIM for everything else)
-- Deduplicate to keep only the closest facility per plume
SELECT DISTINCT ON (id) *
FROM (
    SELECT * FROM rrc_operator_rows
    UNION ALL
    SELECT * FROM ogim_operator_rows
) combined
ORDER BY id, distance_to_nearest_facility_km;

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
    COUNT(DISTINCT entity_name) as unique_operators
FROM emissions.attributed
WHERE entity_name IS NOT NULL
GROUP BY nearest_facility_type
ORDER BY attributed_plumes DESC;
