-- Create emissions attribution table using OGIM multi-infrastructure approach
-- Matches CH4 plumes to nearest wells, compressor stations, processing plants, and tank batteries
-- Applies infrastructure type weighting and calculates confidence scores

-- Ensure spatial extension is loaded
LOAD spatial;

-- Drop existing table
DROP TABLE IF EXISTS emissions.attributed;

-- Create attribution table with infrastructure type weighting
CREATE TABLE emissions.attributed AS
WITH
-- Find all facilities within 750m of each emission source
nearby_facilities AS (
    SELECT
        e.id as emission_id,
        e.geom as emission_geom,
        f.facility_id,
        f.infra_type,
        f.type_weight,
        f.operator,
        f.facility_subtype,
        f.geom as facility_geom,
        ST_Distance(e.geom, f.geom) * 111 as distance_km  -- Convert degrees to km (approximate)
    FROM emissions.sources e
    CROSS JOIN infrastructure.all_facilities f
    WHERE e.gas = 'CH4'
        AND ST_Distance(e.geom, f.geom) < 0.0075  -- ~750m radius
),

-- Calculate total facility counts per emission (all operators)
emission_totals AS (
    SELECT
        emission_id,
        COUNT(*) as total_facilities_within_750m,
        COUNT(*) FILTER (WHERE infra_type = 'well') as wells_within_750m,
        COUNT(*) FILTER (WHERE infra_type = 'compressor') as compressors_within_750m,
        COUNT(*) FILTER (WHERE infra_type = 'processing') as processing_within_750m,
        COUNT(*) FILTER (WHERE infra_type = 'tank_battery') as tanks_within_750m
    FROM nearby_facilities
    GROUP BY emission_id
),

-- Calculate operator-specific counts per emission/type/operator
emission_operator_stats AS (
    SELECT
        emission_id,
        infra_type,
        operator,
        COUNT(*) as operator_facilities_of_type
    FROM nearby_facilities
    GROUP BY emission_id, infra_type, operator
),

-- Find the single best match per emission (closest facility with type weighting)
best_matches AS (
    SELECT DISTINCT ON (nf.emission_id)
        nf.emission_id,
        nf.facility_id,
        nf.infra_type,
        nf.type_weight,
        nf.operator,
        nf.facility_subtype,
        nf.distance_km,
        totals.total_facilities_within_750m,
        totals.wells_within_750m,
        totals.compressors_within_750m,
        totals.processing_within_750m,
        totals.tanks_within_750m,
        op_stats.operator_facilities_of_type,

        -- Distance score (0-35 points): inverse relationship, closer = higher
        -- Max at 0m (35 pts), min at 750m (0 pts)
        GREATEST(0, 35 * (1 - (nf.distance_km / 0.75))) as distance_score,

        -- Operator dominance (0-50 points): % of nearby facilities of same type operated by this operator
        LEAST(50, 50 * (CAST(op_stats.operator_facilities_of_type AS FLOAT) / NULLIF(totals.total_facilities_within_750m, 0))) as operator_dominance_score,

        -- Density penalty (5-15 points): fewer facilities = less ambiguity = higher score
        CASE
            WHEN totals.total_facilities_within_750m = 1 THEN 15
            WHEN totals.total_facilities_within_750m <= 3 THEN 12
            WHEN totals.total_facilities_within_750m <= 10 THEN 9
            WHEN totals.total_facilities_within_750m <= 30 THEN 6
            ELSE 5
        END as density_score

    FROM nearby_facilities nf
    INNER JOIN emission_totals totals
        ON nf.emission_id = totals.emission_id
    INNER JOIN emission_operator_stats op_stats
        ON nf.emission_id = op_stats.emission_id
        AND nf.operator = op_stats.operator
        AND nf.infra_type = op_stats.infra_type
    -- Sort by: 1) type weight (higher first), 2) distance (closer first)
    ORDER BY nf.emission_id, (nf.type_weight / (nf.distance_km + 0.01)) DESC
)

-- Final attribution with confidence scores
SELECT
    e.id,
    e.emission_auto as rate_avg_kg_hr,
    e.emission_uncertainty_auto as rate_uncertainty_kg_hr,
    e.plume_count,
    e.timestamp_min,
    e.timestamp_max,
    ST_Y(e.geom) as latitude,
    ST_X(e.geom) as longitude,
    bm.facility_id as nearest_facility_id,
    bm.infra_type as nearest_facility_type,
    bm.facility_subtype,
    bm.operator as nearest_facility_operator,
    bm.distance_km as distance_to_nearest_facility_km,
    bm.total_facilities_within_750m,
    bm.wells_within_750m,
    bm.compressors_within_750m,
    bm.processing_within_750m,
    bm.tanks_within_750m,
    bm.operator_facilities_of_type,

    -- Calculate final weighted confidence score
    ROUND(
        (bm.distance_score * bm.type_weight) +  -- Type-weighted distance score
        bm.operator_dominance_score +           -- Operator dominance
        bm.density_score,                        -- Density bonus
        1
    ) as confidence_score,

    bm.type_weight as infrastructure_type_weight,
    bm.distance_score,
    bm.operator_dominance_score,
    bm.density_score

FROM emissions.sources e
LEFT JOIN best_matches bm ON e.id = bm.emission_id
WHERE e.gas = 'CH4';

-- Create indexes for fast querying
CREATE INDEX idx_attributed_operator ON emissions.attributed (nearest_facility_operator);
CREATE INDEX idx_attributed_facility_type ON emissions.attributed (nearest_facility_type);
CREATE INDEX idx_attributed_confidence ON emissions.attributed (confidence_score);

-- Summary statistics
SELECT
    nearest_facility_type,
    COUNT(*) as attributed_plumes,
    ROUND(AVG(confidence_score), 1) as avg_confidence,
    ROUND(AVG(distance_to_nearest_facility_km), 2) as avg_distance_km,
    COUNT(DISTINCT nearest_facility_operator) as unique_operators
FROM emissions.attributed
WHERE nearest_facility_operator IS NOT NULL
GROUP BY nearest_facility_type
ORDER BY attributed_plumes DESC;
