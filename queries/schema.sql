-- Texas RRC P-4 Database Schema
-- Faithful representation of EBCDIC file structure

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
  operator_number INTEGER,

  PRIMARY KEY (oil_gas_code, district, lease_rrcid)
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
  p5_number_filing_on_tape INTEGER,

  PRIMARY KEY (oil_gas_code, district, lease_rrcid, sequence_date_key),
  FOREIGN KEY (oil_gas_code, district, lease_rrcid)
    REFERENCES p4.root(oil_gas_code, district, lease_rrcid)
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
  intra_flag VARCHAR(1),                   -- Intrastate market

  FOREIGN KEY (oil_gas_code, district, lease_rrcid, sequence_date_key)
    REFERENCES p4.info(oil_gas_code, district, lease_rrcid, sequence_date_key)
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
  lease_name VARCHAR(32),

  PRIMARY KEY (oil_gas_code, district, lease_rrcid, sequence_date_key),
  FOREIGN KEY (oil_gas_code, district, lease_rrcid, sequence_date_key)
    REFERENCES p4.info(oil_gas_code, district, lease_rrcid, sequence_date_key)
);
