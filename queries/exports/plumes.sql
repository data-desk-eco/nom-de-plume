-- Export top 500 super-emitter plumes for notebook
SELECT
  id,
  entity_name as operator,
  rate_kg_hr,
  datetime,
  latitude,
  longitude,
  nearest_facility_id,
  nearest_facility_type,
  distance_to_nearest_facility_km,
  total_facilities_nearby,
  operator_facilities_of_type,
  confidence_score
FROM emissions.attributed
WHERE rate_kg_hr >= 100
  AND confidence_score >= 75
  AND distance_to_nearest_facility_km <= 0.5
ORDER BY datetime DESC
LIMIT 500
