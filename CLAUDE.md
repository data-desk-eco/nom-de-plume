# Nom de plume

Methane plume attribution system for Texas oil and gas infrastructure.

## Project Goal

Attribute methane plumes observed by satellites to specific owners, operators, and gathering companies of oil and gas infrastructure in Texas.

## Current State

The database is **complete and production-ready** with full attribution capability:

- **1,005,281 wells** with corrected WGS84 coordinates and spatial geometry
- **10,443 emission sources** from Carbon Mapper satellite observations (CH4 and CO2)
- **1,941 CH4 plumes** attributed to operators and purchasers with confidence scores
- **743 plumes** matched to LNG feedgas supply contracts
- **P5 organization data** linking operator/gatherer numbers to company names
- Spatial queries enabled via DuckDB spatial extension
- Complete chain: Plume location → Well → Lease → Operator/Purchaser → LNG Facility
- **LNG supply contracts** from DOE filings parsed by Gemini 2.5 Pro

## Architecture

### Data Pipeline

```
EBCDIC Files → Python Parsers → CSV Files → DuckDB Database
     ↓              ↓              ↓              ↓
  data/*.gz    scripts/*.py   (gitignored)  data.duckdb
```

Build with: `make` or `make data/data.duckdb`

### Database Schema

**P4 Schema** (lease/producer data):
- `p4.root` - 543,920 leases (oil_gas_code + district + lease_rrcid)
- `p4.info` - 3.7M P-4 filings (temporal records)
- `p4.gpn` - 11.9M gatherer/purchaser/nominator records
- `p4.lease_name` - 524K lease names

**Wellbore Schema** (well locations):
- `wellbore.root` - 1.2M wells (API number = api_county + api_unique)
- `wellbore.location` - 1M wells with WGS84 coordinates and **GEOMETRY column**
- `wellbore.wellid` - 661K well-to-lease linkages (THE BRIDGE between systems)

**P5 Schema** (organization data):
- `p5.org` - 77,625 organizations with names and addresses
- `p5.officer` - 182K officer records
- `p5.specialty` - 7,845 specialty codes
- `p5.activity` - 9,905 activity indicators

**Emissions Schema** (satellite observations):
- `emissions.sources` - 10,443 emission sources with **GEOMETRY column**
- `emissions.attributed` - 1,941 CH4 plumes matched to nearest wells with:
  - Operator and purchaser information
  - Confidence scores (0-100) based on proximity, operator dominance, and well density
  - Distance to nearest well and well counts within 500m radius
- Includes CH4 and CO2 plumes from Carbon Mapper
- Fields: emission rate, plume count, persistence, timestamps

### Attribution Chain

```
Satellite Plume (emissions.sources.geom)
    ↓ ST_Distance() / spatial query
Well Location (wellbore.location.geom)
    ↓ api_county, api_unique
Well-ID Bridge (wellbore.wellid)
    ↓ oil_gas_code, district, lease_number/gas_rrcid
P4 Lease (p4.root)
    ↓ oil_gas_code, district, lease_rrcid
    ├→ operator_number → p5.org (operator name)
    └→ Gatherers/Purchasers (p4.gpn)
        → gpn_number → p5.org (gatherer/purchaser name)
        → actual_percent, type_code
```

## Key Design Decisions

1. **No Python dependencies** - Only stdlib, parsers use `cp500` encoding for EBCDIC
2. **DuckDB CLI** - No Python bindings, pure SQL for data loading
3. **Faithful schema** - Field names from Texas RRC documentation
4. **No foreign keys** - Source data has quality issues (duplicates, orphans)
5. **Spatial extension** - GEOMETRY column for efficient spatial queries
6. **CSV intermediate** - Makefile tracks dependencies properly

## File Structure

```
data/
  p4f606.ebc.gz                      # P4 EBCDIC source (203 MB)
  dbf900.ebc.gz                      # Wellbore EBCDIC source (487 MB)
  orf850.ebc.gz                      # P5 organization EBCDIC source (20 MB)
  sources_*.json                     # Carbon Mapper emissions JSON
  supply-contracts-gemini-2-5-pro.csv # LNG feedgas supply agreements from DOE
  *.csv                              # Generated CSVs (gitignored)
  data.duckdb                        # Final database (gitignored)

scripts/
  create_p4_db.py         # P4 EBCDIC → CSV parser
  parse_p4.py             # P4 data structures
  create_wellbore_db.py   # Wellbore EBCDIC → CSV parser
  parse_wellbore.py       # Wellbore data structures
  create_p5_db.py         # P5 EBCDIC → CSV parser
  parse_p5.py             # P5 data structures
  fetch_emissions.py      # Fetch emissions from Carbon Mapper API

queries/
  schema.sql                    # Database schema (loads spatial extension)
  load_p4.sql                   # Load P4 data
  load_wellbore.sql             # Load wellbore data (creates geometry with longitude fix)
  load_p5.sql                   # Load P5 organization data
  load_emissions.sql            # Load emissions data (creates geometry)
  create_indexes.sql            # Create spatial and performance indexes
  create_attribution_table.sql  # Materialize emissions attribution (expensive spatial join)
  emissions_attribution.sql     # Legacy CSV export of attribution
  lng_attribution.sql           # Match attributed plumes to LNG supply contracts

output/
  lng_attribution.csv     # CH4 plumes matched to LNG feedgas suppliers (743 rows)

docs/
  p4-user-manual_p4a002_feb2015.txt    # P4 field documentation
  wba091_well-bore-database.txt        # Wellbore field documentation
  wla001k.txt                           # P5 field documentation
```

## Important Implementation Details

### EBCDIC Parsing
- **Encoding**: Use `cp500` (IBM EBCDIC US/Canada)
- **Signed decimals**: EBCDIC zoned decimal (last byte has sign in zone bits: 0xC=pos, 0xD=neg)
- **Record types**: First 2 bytes identify segment type (01, 02, 03, etc.)

### P4 Structure
- Record 01 (root) = current lease state
- Record 02 (info) = temporal P-4 filing (has sequence_date_key)
- Record 03 (gpn) = gatherers/purchasers for that filing
- Record 07 (lease_name) = lease names (matched by sequence_date_key)
- **Buffering required**: Collect all records per lease before writing

### Wellbore Structure
- Record 01 (root) = well identification (API number)
- Record 13 (location) = WGS84 coordinates (NON-RECURRING)
  - **Longitude sign issue**: RRC data stores Texas longitudes as positive values
  - Fixed in `load_wellbore.sql` with `-ABS(longitude)` to ensure western hemisphere
- Record 21 (wellid) = THE BRIDGE to RRC lease IDs (RECURRING)
  - Oil wells: district + lease_number → p4.root.lease_rrcid
  - Gas wells: gas_rrcid → p4.root.lease_rrcid

### Geometry Columns
Both wells and emissions use PostGIS-style GEOMETRY columns for spatial queries:

```sql
-- Well geometry (created in load_wellbore.sql with longitude sign correction)
ST_Point(-ABS(wgs84_longitude), wgs84_latitude) AS geom

-- Emission geometry (created in load_emissions.sql)
ST_Point(longitude, latitude) AS geom

-- Example: Find nearest well to an emission
SELECT
    e.id as emission_id,
    w.api_county || '-' || w.api_unique as well_api,
    ST_Distance(e.geom, w.geom) * 111 as distance_km
FROM emissions.sources e
CROSS JOIN wellbore.location w
WHERE w.geom IS NOT NULL
ORDER BY ST_Distance(e.geom, w.geom)
LIMIT 1;
```

## Common Queries

### Find emissions near wells operated by a specific company

```sql
-- Install and load spatial extension first
INSTALL spatial;
LOAD spatial;

-- Find emissions within 5km of company's wells
WITH company_wells AS (
    SELECT loc.geom, loc.api_county, loc.api_unique, p4.operator_number, org.organization_name
    FROM wellbore.location loc
    JOIN wellbore.wellid wb ON loc.api_county = wb.api_county
                            AND loc.api_unique = wb.api_unique
    JOIN p4.root p4 ON wb.oil_gas_code = p4.oil_gas_code
                    AND wb.district = p4.district
                    AND (wb.lease_number = p4.lease_rrcid OR wb.gas_rrcid = p4.lease_rrcid)
    LEFT JOIN p5.org org ON p4.operator_number = org.operator_number
    WHERE UPPER(org.organization_name) LIKE '%COMPANY_NAME%'
      AND loc.geom IS NOT NULL
)
SELECT
    e.id,
    e.emission_auto as kg_per_hr,
    e.plume_count,
    ST_Y(e.geom) as lat,
    ST_X(e.geom) as lon,
    w.api_county || '-' || w.api_unique as well_api,
    w.organization_name,
    ROUND(ST_Distance(e.geom, w.geom) * 111, 2) as distance_km
FROM emissions.sources e
JOIN company_wells w ON ST_Distance(e.geom, w.geom) < 0.05  -- ~5km
WHERE e.gas = 'CH4'
ORDER BY e.emission_auto DESC, distance_km;
```

### Find all operators and gatherers for wells near a plume

```sql
SELECT
    loc.api_county || '-' || loc.api_unique as well_api,
    ST_Distance(e.geom, loc.geom) * 111 as distance_km,
    op_org.organization_name as operator_name,
    gpn.type_code,
    gpn_org.organization_name as gatherer_name,
    gpn.actual_percent
FROM emissions.sources e
JOIN wellbore.location loc ON ST_Distance(e.geom, loc.geom) < 0.01  -- ~1km
JOIN wellbore.wellid wb ON loc.api_county = wb.api_county
                        AND loc.api_unique = wb.api_unique
JOIN p4.root p4 ON wb.oil_gas_code = p4.oil_gas_code
                AND wb.district = p4.district
                AND (wb.lease_number = p4.lease_rrcid OR wb.gas_rrcid = p4.lease_rrcid)
LEFT JOIN p5.org op_org ON p4.operator_number = op_org.operator_number
LEFT JOIN p4.gpn gpn ON p4.oil_gas_code = gpn.oil_gas_code
                     AND p4.district = gpn.district
                     AND p4.lease_rrcid = gpn.lease_rrcid
LEFT JOIN p5.org gpn_org ON gpn.gpn_number = gpn_org.operator_number
WHERE e.id = 'CH4_1B2_250m_-99.45098_28.43460'
  AND loc.geom IS NOT NULL
ORDER BY distance_km;
```

## LNG Supply Chain Attribution

The system includes specialized functionality to match attributed plumes to LNG feedgas supply contracts.

### Usage

```bash
# Build database (includes attribution table creation)
make

# Generate LNG attribution report
make lng-attribution
```

### Methodology

1. **Attribution Table** (`emissions.attributed`):
   - Materialized table created during DB build
   - Spatial join matches CH4 plumes to nearest wells within 500m
   - Includes operator names and purchaser lists (type H - purchasers who buy gas)
   - Confidence score (0-100) based on:
     - **Operator Dominance** (0-50): % of nearby wells operated by matched company
     - **Distance** (0-35): Closer plumes score higher
     - **Well Density** (5-15): Fewer nearby wells = less ambiguity

2. **LNG Contract Matching** (`lng_attribution.sql`):
   - Fuzzy string matching (Jaro-Winkler > 0.85) between:
     - Well operators ↔ LNG contract sellers
     - Gas purchasers ↔ LNG contract sellers
   - Matches both producers (Apache, Pioneer) and marketers (Chevron, Enterprise)
   - One row per emission source with aggregated LNG supplier info

### Output Format

`output/lng_attribution.csv` contains:
- Plume details (ID, location, emission rates, timestamps)
- Attribution (nearest well, operator, purchasers, confidence score)
- LNG matches (sellers, projects, match count, similarity scores)

### Why Purchasers Matter

Purchasers (type H in RRC data) are the companies that:
- Buy gas from producers at the wellhead
- Act as marketers/aggregators
- Sign supply contracts with LNG facilities

Gatherers (type G) provide transportation services only and don't appear in LNG supply contracts, so they're excluded from matching.

## Database Schema Reference

Full schema definitions with field descriptions are in:
- `queries/schema.sql` - Complete DDL with all tables and columns
- `docs/p4-user-manual_p4a002_feb2015.txt` - P4 field documentation
- `docs/wba091_well-bore-database.txt` - Wellbore field documentation
- `docs/wla001k.txt` - P5 organization field documentation

To explore the schema interactively:
```bash
duckdb data/data.duckdb
D DESCRIBE p4.root;        # Show P4 root table structure
D DESCRIBE wellbore.location;  # Show wellbore location table
D DESCRIBE emissions.sources;  # Show emissions table
```

## Future Work

- Build spatial indexes for faster queries (R-tree on geometry columns)
- Add temporal analysis (track ownership/gathering changes over time)
- Parse additional EBCDIC datasets (pipelines, compressor stations)
- Export to GeoJSON/Shapefile for GIS tools
- Add regular emissions data updates from Carbon Mapper API

## Development Guidelines

- **Always use uv for Python** (per global CLAUDE.md)
- **Minimal code** - Prefer simple, obvious solutions
- **Faithful to source** - Use field names from RRC documentation
- **No unnecessary files** - Keep repo clean
- **Test on samples first** - EBCDIC files are large
- **Document data quality issues** - Source has duplicates, missing foreign keys
- When editing computationally expensive SQL queries, always add a limit clause in a sensible place to make it run faster during testing, then remove it for production. This saves a lot of waiting around.