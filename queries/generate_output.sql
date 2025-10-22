-- LNG Feedgas Supply Attribution Query
-- Joins attributed plumes with operators AND purchasers, then fuzzy-matches to LNG sellers
-- Returns one row per emission source with summarized LNG supplier matches

-- Load LNG contracts
WITH lng_contracts AS (
    SELECT * FROM read_csv_auto('data/supply-contracts-gemini-2-5-pro.csv')
),

-- Get best plume attribution (one row per plume) with operator
-- Filter to high-confidence matches (>= 75) and select best match per plume
plume_info AS (
    SELECT DISTINCT ON (id)
        id,
        rate_kg_hr,
        rate_uncertainty_kg_hr,
        datetime,
        latitude,
        longitude,
        nearest_facility_id,
        nearest_facility_type,
        distance_to_nearest_facility_km,
        total_facilities_nearby,
        operator_facilities_of_type,
        confidence_score,
        entity_name as operator
    FROM emissions.attributed
    WHERE entity_type = 'operator'
      AND confidence_score >= 75
    ORDER BY id, confidence_score DESC, distance_to_nearest_facility_km ASC
),

-- Get Texas well details for purchaser lookup
texas_wells AS (
    SELECT DISTINCT
        a.id,
        a.nearest_facility_id,
        SPLIT_PART(a.nearest_facility_id, '-', 1) as api_county,
        SPLIT_PART(a.nearest_facility_id, '-', 2) as api_unique
    FROM emissions.attributed a
    WHERE a.nearest_facility_type = 'well'
      AND a.nearest_facility_id LIKE '%-%'  -- Texas API format
),

-- Join to wellbore data to get RRC identifiers
well_rrc_ids AS (
    SELECT
        tw.id,
        tw.nearest_facility_id,
        wb.oil_gas_code,
        wb.district,
        COALESCE(wb.lease_number, wb.gas_rrcid) as lease_rrcid
    FROM texas_wells tw
    JOIN wellbore.wellid wb
        ON tw.api_county = wb.api_county
        AND tw.api_unique = wb.api_unique
),

-- Get purchasers for Texas wells
texas_purchasers AS (
    SELECT
        w.id,
        'purchaser' as entity_type,
        gpn_org.organization_name as entity_name
    FROM well_rrc_ids w
    JOIN p4.gpn gpn
        ON w.oil_gas_code = gpn.oil_gas_code
        AND w.district = gpn.district
        AND w.lease_rrcid = gpn.lease_rrcid
    LEFT JOIN p5.org gpn_org ON gpn.gpn_number = gpn_org.operator_number
    WHERE gpn.type_code = 'H'  -- H = purchaser
      AND gpn.gpn_number IS NOT NULL
      AND gpn_org.organization_name IS NOT NULL
),

-- Combine operators and purchasers for matching
all_entities AS (
    SELECT
        id,
        'operator' as entity_type,
        operator as entity_name
    FROM plume_info
    WHERE operator IS NOT NULL
    UNION ALL
    SELECT
        id,
        entity_type,
        entity_name
    FROM texas_purchasers
),

-- Fuzzy match all entities (operators + purchasers) to LNG sellers
entity_matches AS (
    SELECT
        e.id,
        e.entity_type,
        e.entity_name,
        c.Seller as matched_seller,
        c.LNG_Project,
        ROUND(jaro_winkler_similarity(UPPER(e.entity_name), UPPER(c.Seller)), 3) as similarity_score
    FROM all_entities e
    CROSS JOIN lng_contracts c
    WHERE e.entity_name IS NOT NULL
      AND jaro_winkler_similarity(UPPER(e.entity_name), UPPER(c.Seller)) > 0.85
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
    p.rate_kg_hr,
    p.rate_uncertainty_kg_hr,
    p.datetime,
    p.latitude,
    p.longitude,
    p.nearest_facility_id,
    p.nearest_facility_type,
    p.distance_to_nearest_facility_km,
    p.total_facilities_nearby,
    p.operator_facilities_of_type,
    p.confidence_score,
    m.lng_matches,
    m.lng_seller_count
FROM plume_info p
INNER JOIN aggregated_matches m ON p.id = m.id
ORDER BY p.datetime DESC, p.rate_kg_hr DESC NULLS LAST;
