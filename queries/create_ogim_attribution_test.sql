-- TEST VERSION: Create emissions attribution table using OGIM multi-infrastructure approach
-- Processes only 10 emissions for testing

-- Ensure spatial extension is loaded
LOAD spatial;

-- Drop existing table
DROP TABLE IF EXISTS emissions.attributed;

-- Create attribution table with infrastructure type weighting
CREATE TABLE emissions.attributed AS
WITH
-- LIMIT emissions for testing (Texas only: lon between -106 and -93, lat between 26 and 36)
test_emissions AS (
    SELECT * FROM emissions.sources
    WHERE gas = 'CH4'
        AND ST_X(geom) BETWEEN -106 AND -93
        AND ST_Y(geom) BETWEEN 26 AND 36
    LIMIT 10
),

-- Find all facilities within 500m of each emission source
nearby_facilities AS (
    SELECT
        e.id as emission_id,
        e.geom as emission_geom,
        f.facility_id,
        f.infra_type,
        f.operator,
        f.facility_subtype,
        f.geom as facility_geom,
        ST_Distance(e.geom, f.geom) * 111 as distance_km  -- Convert degrees to km (approximate)
    FROM test_emissions e
    CROSS JOIN infrastructure.all_facilities f
    WHERE ST_Distance(e.geom, f.geom) < 0.005  -- ~500m radius
),

-- Calculate operator dominance and facility density per emission
emission_stats AS (
    SELECT
        emission_id,
        infra_type,
        operator,
        COUNT(*) as facilities_within_500m,
        COUNT(*) FILTER (WHERE infra_type = 'well') as wells_within_500m,
        COUNT(*) FILTER (WHERE infra_type = 'compressor') as compressors_within_500m,
        COUNT(*) FILTER (WHERE infra_type = 'processing') as processing_within_500m,
        COUNT(*) FILTER (WHERE infra_type = 'tank_battery') as tanks_within_500m,
        COUNT(*) FILTER (WHERE operator = nf.operator AND infra_type = nf.infra_type) as operator_facilities_of_type
    FROM nearby_facilities nf
    GROUP BY emission_id, infra_type, operator
),

-- Find the single best match per emission (closest facility with type weighting)
best_matches AS (
    SELECT DISTINCT ON (nf.emission_id)
        nf.emission_id,
        nf.facility_id,
        nf.infra_type,
        nf.operator,
        nf.facility_subtype,
        nf.distance_km,
        stats.facilities_within_500m,
        stats.wells_within_500m,
        stats.compressors_within_500m,
        stats.processing_within_500m,
        stats.tanks_within_500m,
        stats.operator_facilities_of_type,

        -- Distance score (0-35 points): inverse relationship, closer = higher
        -- Max at 0m (35 pts), min at 500m (0 pts)
        GREATEST(0, 35 * (1 - (nf.distance_km / 0.5))) as distance_score,

        -- Operator dominance (0-50 points): % of nearby facilities of same type operated by this operator
        LEAST(50, 50 * (CAST(stats.operator_facilities_of_type AS FLOAT) / NULLIF(stats.facilities_within_500m, 0))) as operator_dominance_score,

        -- Density penalty (5-15 points): fewer facilities = less ambiguity = higher score
        CASE
            WHEN stats.facilities_within_500m = 1 THEN 15
            WHEN stats.facilities_within_500m <= 3 THEN 12
            WHEN stats.facilities_within_500m <= 10 THEN 9
            WHEN stats.facilities_within_500m <= 30 THEN 6
            ELSE 5
        END as density_score

    FROM nearby_facilities nf
    INNER JOIN emission_stats stats
        ON nf.emission_id = stats.emission_id
        AND nf.operator = stats.operator
        AND nf.infra_type = stats.infra_type
    -- Sort by distance (closer first)
    ORDER BY nf.emission_id, nf.distance_km ASC
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
    bm.facilities_within_500m as total_facilities_within_500m,
    bm.wells_within_500m,
    bm.compressors_within_500m,
    bm.processing_within_500m,
    bm.tanks_within_500m,
    bm.operator_facilities_of_type,

    -- Calculate final confidence score
    ROUND(
        bm.distance_score +                     -- Distance score (0-35)
        bm.operator_dominance_score +           -- Operator dominance (0-50)
        bm.density_score,                        -- Density bonus (5-15)
        1
    ) as confidence_score

FROM test_emissions e
LEFT JOIN best_matches bm ON e.id = bm.emission_id;

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
