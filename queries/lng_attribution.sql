-- LNG Feedgas Supply Attribution Query
-- Joins attributed plumes with LNG feedgas supply agreements using fuzzy matching
-- Returns one row per emission source with summarized LNG supplier matches

-- Parse purchaser names from semicolon-delimited string
WITH purchaser_parsed AS (
    SELECT
        a.*,
        UNNEST(STRING_SPLIT(a.purchaser_names, '; ')) as purchaser_entry
    FROM emissions.attributed a
    WHERE a.purchaser_names IS NOT NULL
),
purchaser_cleaned AS (
    SELECT
        id,
        REGEXP_REPLACE(purchaser_entry, '^\[\d+\]\s*', '') as purchaser_name
    FROM purchaser_parsed
),

-- Load LNG contracts
lng_contracts AS (
    SELECT * FROM read_csv_auto('data/supply-contracts-gemini-2-5-pro.csv')
),

-- Fuzzy match operators to LNG sellers
operator_matches AS (
    SELECT
        a.id,
        c.Seller as matched_seller,
        c.LNG_Project,
        ROUND(jaro_winkler_similarity(UPPER(a.nearest_well_operator), UPPER(c.Seller)), 3) as similarity_score
    FROM emissions.attributed a
    CROSS JOIN lng_contracts c
    WHERE a.nearest_well_operator IS NOT NULL
      AND jaro_winkler_similarity(UPPER(a.nearest_well_operator), UPPER(c.Seller)) > 0.85
),

-- Fuzzy match purchasers to LNG sellers
purchaser_matches AS (
    SELECT
        p.id,
        c.Seller as matched_seller,
        c.LNG_Project,
        ROUND(jaro_winkler_similarity(UPPER(p.purchaser_name), UPPER(c.Seller)), 3) as similarity_score
    FROM purchaser_cleaned p
    CROSS JOIN lng_contracts c
    WHERE p.purchaser_name IS NOT NULL
      AND jaro_winkler_similarity(UPPER(p.purchaser_name), UPPER(c.Seller)) > 0.85
),

-- Combine and deduplicate matches by emission source
unique_matches AS (
    SELECT DISTINCT
        id,
        matched_seller,
        LNG_Project,
        similarity_score
    FROM (
        SELECT * FROM operator_matches
        UNION ALL
        SELECT * FROM purchaser_matches
    ) combined
),

-- Aggregate matches by emission source
aggregated_matches AS (
    SELECT
        id,
        STRING_AGG(matched_seller || ' (' || similarity_score || ')', '; ' ORDER BY similarity_score DESC) as lng_sellers,
        STRING_AGG(DISTINCT LNG_Project, '; ') as lng_projects,
        COUNT(DISTINCT matched_seller) as lng_match_count,
        MAX(similarity_score) as max_similarity
    FROM unique_matches
    GROUP BY id
)

-- Final output: one row per emission source
SELECT
    a.id,
    a.rate_avg_kg_hr,
    a.rate_detected_kg_hr,
    a.plume_count,
    a.timestamp_min,
    a.timestamp_max,
    a.latitude,
    a.longitude,
    a.nearest_well_api,
    a.nearest_well_operator,
    a.field_number,
    a.lease_name,
    a.purchaser_names,
    a.distance_to_nearest_well_km,
    a.total_wells_within_500m,
    a.operator_wells_within_500m,
    a.confidence_score,
    m.lng_sellers,
    m.lng_projects,
    m.lng_match_count,
    m.max_similarity
FROM emissions.attributed a
JOIN aggregated_matches m ON a.id = m.id
ORDER BY a.timestamp_max DESC, a.rate_detected_kg_hr DESC NULLS LAST;
