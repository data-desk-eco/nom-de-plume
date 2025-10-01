-- LNG Feedgas Supply Attribution Query (OGIM version)
-- Joins attributed plumes with LNG feedgas supply agreements using fuzzy matching
-- Returns one row per emission source with summarized LNG supplier matches
--
-- Note: OGIM data only includes operator information, not purchaser/gatherer details

-- Load LNG contracts
WITH lng_contracts AS (
    SELECT * FROM read_csv_auto('data/supply-contracts-gemini-2-5-pro.csv')
),

-- Fuzzy match facility operators to LNG sellers
operator_matches AS (
    SELECT
        a.id,
        c.Seller as matched_seller,
        c.LNG_Project,
        ROUND(jaro_winkler_similarity(UPPER(a.nearest_facility_operator), UPPER(c.Seller)), 3) as similarity_score
    FROM emissions.attributed a
    CROSS JOIN lng_contracts c
    WHERE a.nearest_facility_operator IS NOT NULL
      AND jaro_winkler_similarity(UPPER(a.nearest_facility_operator), UPPER(c.Seller)) > 0.85
),

-- Aggregate matches by emission source
aggregated_matches AS (
    SELECT
        id,
        STRING_AGG(matched_seller || ' (' || similarity_score || ')', '; ' ORDER BY similarity_score DESC) as lng_sellers,
        STRING_AGG(DISTINCT LNG_Project, '; ') as lng_projects,
        COUNT(DISTINCT matched_seller) as lng_match_count,
        MAX(similarity_score) as max_similarity
    FROM operator_matches
    GROUP BY id
)

-- Final output: one row per emission source
SELECT
    a.id,
    a.rate_avg_kg_hr,
    a.rate_uncertainty_kg_hr,
    a.plume_count,
    a.timestamp_min,
    a.timestamp_max,
    a.latitude,
    a.longitude,
    a.nearest_facility_id,
    a.facility_subtype,
    a.nearest_facility_operator,
    a.distance_to_nearest_facility_km,
    a.total_facilities_within_500m,
    a.operator_facilities_of_type,
    a.confidence_score,
    m.lng_sellers,
    m.lng_projects,
    m.lng_match_count,
    m.max_similarity
FROM emissions.attributed a
LEFT JOIN aggregated_matches m ON a.id = m.id
WHERE m.lng_match_count > 0  -- Only show emissions with LNG matches
ORDER BY a.timestamp_max DESC, a.rate_avg_kg_hr DESC NULLS LAST;
