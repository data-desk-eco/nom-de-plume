-- Export infrastructure within 1.5km of super-emitter plumes
WITH plume_locations AS (
  SELECT id, latitude, longitude
  FROM emissions.attributed
  WHERE rate_kg_hr >= 100
    AND confidence_score >= 75
    AND distance_to_nearest_facility_km <= 0.5
  ORDER BY datetime DESC
  LIMIT 500
)
SELECT
  p.id as plume_id,
  f.facility_id,
  f.infra_type,
  f.operator,
  f.facility_subtype,
  ST_Y(f.geom) as latitude,
  ST_X(f.geom) as longitude,
  ROUND(ST_Distance_Sphere(
    ST_Point(p.longitude, p.latitude),
    f.geom
  ), 0) as distance_m
FROM plume_locations p
CROSS JOIN infra.all_facilities f
WHERE ST_DWithin(
  ST_Point(p.longitude, p.latitude),
  f.geom,
  0.015
)
ORDER BY p.id, distance_m
