-- Texas RRC Database Schema
-- Faithful representation of EBCDIC file structure

-- Install and load spatial extension for geometry types
INSTALL spatial;
LOAD spatial;

CREATE SCHEMA p4;

-- Record Type 01: Lease/P-4 Root Information (P4ROOT segment)
-- One record per lease - represents current schedule state
CREATE TABLE p4.root (
  -- ROOT-KEY
  oil_gas_code VARCHAR NOT NULL,           -- 'O' or 'G'
  district INTEGER NOT NULL,
  lease_rrcid INTEGER NOT NULL,

  -- SCHEDULE-INDEX
  field_number INTEGER,
  on_off_schedule_indicator VARCHAR(1),    -- 'Y' = off schedule, 'N' = on schedule
  operator_number INTEGER

  -- Note: Primary keys removed due to duplicate records in source data
);

-- Record Type 02: P-4 General Information (P4INFO segment)
-- Multiple records per lease - one for each P-4 filing
CREATE TABLE p4.info (
  -- Lease identifier (foreign key to root)
  oil_gas_code VARCHAR NOT NULL,
  district INTEGER NOT NULL,
  lease_rrcid INTEGER NOT NULL,

  -- Keys
  sequence_date_key INTEGER NOT NULL,      -- Uniquely identifies this P-4 filing
  effective_date_key INTEGER,

  -- Dates
  effective_year INTEGER,
  effective_month INTEGER,
  effective_day INTEGER,
  approval_year INTEGER,
  approval_month INTEGER,
  approval_day INTEGER,

  -- Type change flags (Y/N)
  new_well VARCHAR(1),
  change_of_gatherer VARCHAR(1),
  change_of_purchaser VARCHAR(1),
  change_of_nominator VARCHAR(1),
  chg_purch_system_no VARCHAR(1),
  change_of_field VARCHAR(1),
  change_of_operator VARCHAR(1),
  change_of_lease_name VARCHAR(1),
  consolidation_lease VARCHAR(1),
  subdivision_lease VARCHAR(1),
  reclassification VARCHAR(1),
  special_form_filed VARCHAR(1),
  oil_field_transfer VARCHAR(1),

  -- Other fields
  type_record VARCHAR(1),                  -- 'O'=original, 'R'=regular, etc.
  info_field_number INTEGER,
  info_operator_number INTEGER,
  p5_number_filing_on_tape INTEGER

  -- Note: Primary keys removed due to duplicate records in source data
);

-- Record Type 03: P-4 Gatherer/Purchaser/Nominator (P4GPN segment)
-- Multiple records per P-4 filing
CREATE TABLE p4.gpn (
  -- Foreign key to info
  oil_gas_code VARCHAR NOT NULL,
  district INTEGER NOT NULL,
  lease_rrcid INTEGER NOT NULL,
  sequence_date_key INTEGER NOT NULL,

  -- GPN data
  product_code VARCHAR(1),                 -- F=full stream, G=gas, H=condensate, O=oil, P=casing
  type_code VARCHAR(1),                    -- G=gatherer, H=purchaser, I=nominator
  percentage_key DECIMAL(5,4),
  gpn_number INTEGER,                      -- P-5 organization number
  purch_system_no INTEGER,
  current_p4_filing VARCHAR(1),
  actual_percent DECIMAL(5,4),
  inter_flag VARCHAR(1),                   -- Interstate market
  intra_flag VARCHAR(1)                    -- Intrastate market
);

-- Record Type 07: P-4 Lease Name (P4LSENM segment)
-- Only exists for P-4 filings that designated or changed the lease name
CREATE TABLE p4.lease_name (
  -- Foreign key (but note: sequence_date_key is the key for this name)
  oil_gas_code VARCHAR NOT NULL,
  district INTEGER NOT NULL,
  lease_rrcid INTEGER NOT NULL,

  -- LEASE-NAME-INDEX
  sequence_date_key INTEGER NOT NULL,      -- Matches sequence_date_key in info
  effect_date_key INTEGER,
  lease_name VARCHAR(32)

  -- Note: Foreign keys removed due to data quality issues in source files
);


-- ============================================================================
-- Texas RRC Well Bore Database Schema
-- ============================================================================

CREATE SCHEMA wellbore;

-- Record Type 01: Well Bore Root (WBROOT segment)
-- One record per well bore - API number is unique well identifier
CREATE TABLE wellbore.root (
  -- API Number (unique well identifier)
  api_county INTEGER NOT NULL,
  api_unique INTEGER NOT NULL,

  -- Location
  field_district INTEGER,
  res_county_code INTEGER,

  -- Completion date
  orig_compl_century INTEGER,
  orig_compl_year INTEGER,
  orig_compl_month INTEGER,
  orig_compl_day INTEGER,

  -- Well data
  total_depth INTEGER,
  newest_drill_permit_nbr INTEGER,

  -- Status flags
  fresh_water_flag VARCHAR(1),             -- 'Y' = fresh water well
  plug_flag VARCHAR(1),                    -- 'Y' = plugged
  completion_data_ind VARCHAR(1)           -- 'Y' = completion data on file

  -- Note: Primary keys removed due to duplicate records in source data
);

-- Record Type 13: Well Bore New Location (WBNEWLOC segment)
-- One record per well bore - contains WGS84 coordinates
CREATE TABLE wellbore.location (
  -- Foreign key to root
  api_county INTEGER NOT NULL,
  api_unique INTEGER NOT NULL,

  -- Location identifiers
  loc_county INTEGER,
  abstract VARCHAR,
  survey VARCHAR(55),
  block_number VARCHAR(10),
  section VARCHAR(8),
  alt_section VARCHAR(4),
  alt_abstract VARCHAR(6),

  -- Distance from survey lines
  feet_from_sur_sect_1 INTEGER,
  direc_from_sur_sect_1 VARCHAR(13),
  feet_from_sur_sect_2 INTEGER,
  direc_from_sur_sect_2 VARCHAR(13),

  -- WGS84 Coordinates
  wgs84_latitude DOUBLE,
  wgs84_longitude DOUBLE,
  geom GEOMETRY,                           -- Point geometry derived from lat/lon

  -- Texas State Plane Coordinates
  plane_zone INTEGER,
  plane_coordinate_east DOUBLE,
  plane_coordinate_north DOUBLE,

  -- Verification status
  verification_flag VARCHAR(1)             -- 'Y' = verified, 'N' = not verified, 'C' = verified with change

  -- Note: Foreign keys removed due to data quality issues in source files
);

-- Record Type 21: Well Bore Well-ID (WBWELLID segment)
-- Multiple records per well bore - links API number to RRC lease identifiers
-- This is THE BRIDGE that connects wellbore data to P4 lease data
CREATE TABLE wellbore.wellid (
  -- Foreign key to root
  api_county INTEGER NOT NULL,
  api_unique INTEGER NOT NULL,

  -- RRC Lease identifiers (links to p4.root)
  oil_gas_code VARCHAR(1) NOT NULL,        -- 'O' = oil, 'G' = gas
  district INTEGER NOT NULL,

  -- For oil wells: lease_number + well_number
  lease_number INTEGER,                    -- 5 digits - links to p4.root.lease_rrcid
  well_number VARCHAR(6),                  -- 6 character well number

  -- For gas wells: gas_rrcid (6 digits)
  gas_rrcid INTEGER                        -- Links to p4.root.lease_rrcid for gas wells

  -- Note: Foreign keys removed due to data quality issues in source files
);


-- ============================================================================
-- Emissions (Carbon Mapper satellite observations)
-- ============================================================================

CREATE SCHEMA emissions;

-- Emission sources detected by Carbon Mapper (CH4, CO2, etc.)
CREATE TABLE emissions.sources (
  id VARCHAR PRIMARY KEY,
  geom GEOMETRY,

  -- Gas and sector
  gas VARCHAR,                             -- Gas type (e.g., CH4)
  sector VARCHAR,                          -- IPCC sector code (e.g., 6A = Oil and Gas)

  -- Plume observations
  plume_count INTEGER,
  detection_date_count INTEGER,
  observation_date_count INTEGER,

  -- Emissions data
  emission_auto DOUBLE,                    -- Auto-calculated emission rate (kg/hr)
  emission_uncertainty_auto DOUBLE,        -- Uncertainty in emission rate

  -- Temporal coverage
  timestamp_min DATE,
  timestamp_max DATE,
  published_at_min DATE,
  published_at_max DATE,

  -- Persistence
  persistence DOUBLE,                      -- Fraction of observations with detection

  -- Metadata
  source_name VARCHAR
);
