-- Create spatial indexes for faster distance queries
-- R-tree indexes significantly speed up ST_Distance operations

INSTALL spatial;
LOAD spatial;

-- Index on wellbore locations
CREATE INDEX idx_wellbore_location_geom
ON wellbore.location USING RTREE (geom);

-- Index on emissions sources
CREATE INDEX idx_emissions_sources_geom
ON emissions.sources USING RTREE (geom);
