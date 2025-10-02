-- LNG Feedgas Supply Attribution Query
-- Joins attributed plumes (one row per plume-entity) with LNG feedgas supply agreements
-- Matches both operators and purchasers to LNG sellers using fuzzy matching
-- Returns one row per emission source with summarized LNG supplier matches

-- Load LNG contracts
WITH lng_contracts AS (
    SELECT * FROM read_csv_auto('data/supply-contracts-gemini-2-5-pro.csv')
),

-- Get base plume info (one row per plume)
plume_info AS (
    SELECT DISTINCT ON (id)
        id,
        rate_avg_kg_hr,
        rate_detected_kg_hr,
        rate_uncertainty_kg_hr,
        plume_count,
        timestamp_min,
        timestamp_max,
        latitude,
        longitude,
        nearest_facility_id,
        facility_subtype,
        nearest_facility_type,
        distance_to_nearest_facility_km,
        total_facilities_within_750m,
        operator_facilities_of_type,
        confidence_score,
        entity_name as operator  -- Add operator name
    FROM emissions.attributed
    WHERE entity_type = 'operator'  -- Use operator row for base plume info
    ORDER BY id
),

-- Fuzzy match entities (operators + purchasers) to LNG sellers
entity_matches AS (
    SELECT
        a.id,
        a.entity_type,
        a.entity_name,
        c.Seller as matched_seller,
        c.LNG_Project,
        ROUND(jaro_winkler_similarity(UPPER(a.entity_name), UPPER(c.Seller)), 3) as similarity_score
    FROM emissions.attributed a
    CROSS JOIN lng_contracts c
    WHERE a.entity_name IS NOT NULL
      AND jaro_winkler_similarity(UPPER(a.entity_name), UPPER(c.Seller)) > 0.85
),

-- Deduplicate matches (unique entity_type + entity_name + matched_seller combinations)
unique_matches AS (
    SELECT DISTINCT
        id,
        entity_type,
        entity_name,
        matched_seller,
        similarity_score
    FROM entity_matches
),

-- Aggregate matches by emission source
aggregated_matches AS (
    SELECT
        id,
        STRING_AGG(
            entity_type || ': ' || entity_name || ' → ' || matched_seller || ' (' || similarity_score || ')',
            '; '
            ORDER BY similarity_score DESC
        ) as lng_matches,
        COUNT(DISTINCT matched_seller) as lng_seller_count
    FROM unique_matches
    GROUP BY id
)

-- Final output: one row per emission source with LNG matches
SELECT
    p.id,
    p.operator,
    p.rate_avg_kg_hr,
    p.rate_detected_kg_hr,
    p.rate_uncertainty_kg_hr,
    p.plume_count,
    p.timestamp_min,
    p.timestamp_max,
    p.latitude,
    p.longitude,
    p.nearest_facility_id,
    p.nearest_facility_type,
    p.facility_subtype,
    p.distance_to_nearest_facility_km,
    p.total_facilities_within_750m,
    p.operator_facilities_of_type,
    p.confidence_score,
    m.lng_matches,
    m.lng_seller_count
FROM plume_info p
INNER JOIN aggregated_matches m ON p.id = m.id
ORDER BY p.timestamp_max DESC, p.rate_avg_kg_hr DESC NULLS LAST;
