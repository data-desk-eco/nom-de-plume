-- Create spatial indexes for faster distance queries
-- R-tree indexes significantly speed up ST_Distance operations

INSTALL spatial;
LOAD spatial;

-- Spatial indexes
CREATE INDEX idx_wellbore_location_geom
ON wellbore.location USING RTREE (geom);

CREATE INDEX idx_emissions_sources_geom
ON emissions.sources USING RTREE (geom);

-- Indexes for P4 GPN joins (11.9M rows)
CREATE INDEX idx_p4_gpn_lease
ON p4.gpn (oil_gas_code, district, lease_rrcid);

CREATE INDEX idx_p4_gpn_number
ON p4.gpn (gpn_number);
