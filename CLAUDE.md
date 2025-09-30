# Nom de plume

Methane plume attribution system for Texas oil and gas infrastructure.

## Project Goal

Attribute methane plumes observed by satellites to specific owners, operators, and gathering companies of oil and gas infrastructure in Texas.

## Current State

The database is **complete and production-ready** with full attribution capability:

- **351,145 wells** with coordinates linked to gathering companies
- Spatial queries enabled via DuckDB spatial extension
- Complete chain: Plume location → Well → Lease → Gatherer/Purchaser

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

### Attribution Chain

```
Satellite Plume (lat/lon)
    ↓ ST_Distance() / spatial query
Well Location (wellbore.location.geom)
    ↓ api_county, api_unique
Well-ID Bridge (wellbore.wellid)
    ↓ oil_gas_code, district, lease_number/gas_rrcid
P4 Lease (p4.root)
    ↓ oil_gas_code, district, lease_rrcid
Gatherers/Purchasers (p4.gpn)
    → gpn_number, actual_percent, type_code
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
  p4f606.ebc.gz           # P4 EBCDIC source (203 MB)
  dbf900.ebc.gz           # Wellbore EBCDIC source (487 MB)
  *.csv                   # Generated CSVs (gitignored)
  data.duckdb             # Final database (gitignored)

scripts/
  create_p4_db.py         # P4 EBCDIC → CSV parser
  parse_p4.py             # P4 data structures
  create_wellbore_db.py   # Wellbore EBCDIC → CSV parser
  parse_wellbore.py       # Wellbore data structures

queries/
  schema.sql              # Database schema (loads spatial extension)
  load_db.sql             # Load P4 data
  load_wellbore.sql       # Load wellbore data (creates geometry)

docs/
  p4-user-manual_p4a002_feb2015.txt
  wba091_well-bore-database.txt
  wla001k.txt
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
- Record 21 (wellid) = THE BRIDGE to RRC lease IDs (RECURRING)
  - Oil wells: district + lease_number → p4.root.lease_rrcid
  - Gas wells: gas_rrcid → p4.root.lease_rrcid

### Geometry Column
```sql
-- Created in load_wellbore.sql
ST_Point(longitude, latitude) AS geom

-- Usage for nearest well query:
SELECT api_county, api_unique,
       ST_Distance(geom, ST_Point(-96.5, 32.0)) as distance
FROM wellbore.location
WHERE geom IS NOT NULL
ORDER BY distance
LIMIT 1;
```

## Common Queries

Find wells with gatherers near a plume:
```sql
SELECT
    wb.api_county, wb.api_unique,
    loc.wgs84_latitude, loc.wgs84_longitude,
    gpn.gpn_number, gpn.actual_percent, gpn.type_code
FROM wellbore.location loc
JOIN wellbore.wellid wb ON loc.api_county = wb.api_county
                        AND loc.api_unique = wb.api_unique
JOIN p4.root p4 ON wb.oil_gas_code = p4.oil_gas_code
                AND wb.district = p4.district
                AND (wb.lease_number = p4.lease_rrcid OR wb.gas_rrcid = p4.lease_rrcid)
JOIN p4.gpn gpn ON p4.oil_gas_code = gpn.oil_gas_code
                AND p4.district = gpn.district
                AND p4.lease_rrcid = gpn.lease_rrcid
WHERE loc.geom IS NOT NULL
  AND ST_Distance(loc.geom, ST_Point(-96.5, 32.0)) < 0.01  -- ~1km
ORDER BY ST_Distance(loc.geom, ST_Point(-96.5, 32.0));
```

## Future Work

- Parse additional EBCDIC datasets (pipelines, compressor stations)
- Integrate satellite plume observations
- Build spatial indexing for faster queries
- Add temporal analysis (track ownership/gathering changes over time)
- Export to GeoJSON/Shapefile for GIS tools

## Development Guidelines

- **Always use uv for Python** (per global CLAUDE.md)
- **Minimal code** - Prefer simple, obvious solutions
- **Faithful to source** - Use field names from RRC documentation
- **No unnecessary files** - Keep repo clean
- **Test on samples first** - EBCDIC files are large
- **Document data quality issues** - Source has duplicates, missing foreign keys
