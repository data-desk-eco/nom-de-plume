# Nom de plume

Methane plume attribution system for Texas and Louisiana oil and gas infrastructure.

## Project Goal

Attribute methane plumes observed by satellites to specific operators of oil and gas infrastructure in Texas and Louisiana.

## Current State

The database is **complete and production-ready** with full attribution capability:

- **970,362 wells** from OGIM v2.7 with WGS84 coordinates and spatial geometry
- **561 compressor stations**, **176 processing plants**, **24 tank batteries**
- **10,443 emission sources** from Carbon Mapper satellite observations (CH4 and CO2)
- **290 CH4 plumes** attributed to infrastructure operators with confidence scores
- **52 plumes** matched to LNG feedgas supply contracts
- Spatial queries enabled via DuckDB spatial extension
- Multi-infrastructure attribution: Plume location → Nearest facility (well/compressor/processing/tank) → Operator → LNG Facility
- **LNG supply contracts** from DOE filings parsed by Gemini 2.5 Pro

## Architecture

### Data Pipeline

```
OGIM GeoPackage + Carbon Mapper GeoJSON → DuckDB Database
         ↓                                        ↓
  data/OGIM_v2.7.gpkg                      data.duckdb
  (auto-downloaded via curl)
  data/sources.json
  (auto-fetched via curl)
```

Build with: `make` (fully automated, downloads all data)

### Database Schema

**Infrastructure Schema** (OGIM data):
- `infrastructure.all_facilities` - 970K+ facilities with unified schema:
  - Wells (weight=1.0): 970K Texas and Louisiana wells
  - Processing plants (weight=2.0): 176 facilities
  - Compressor stations (weight=1.5): 561 facilities
  - Tank batteries (weight=1.3): 24 facilities
  - Fields: facility_id, infra_type, type_weight, operator, facility_subtype, status, latitude, longitude, **GEOMETRY column**

**Emissions Schema** (Carbon Mapper observations):
- `emissions.sources` - 10,443 emission sources with **GEOMETRY column**
- `emissions.attributed` - 290 CH4 plumes matched to nearest facilities with:
  - Operator information (directly from OGIM)
  - Infrastructure type (well/compressor/processing/tank_battery)
  - Confidence scores (22-92) based on:
    - **Distance** (0-35 points): Closer plumes score higher, max at 0m (35 pts), min at 750m (0 pts)
    - **Operator Dominance** (0-50 points): % of nearby facilities of same type operated by matched operator
    - **Facility Density** (5-15 points): Fewer nearby facilities = less ambiguity = higher score
  - Distance to nearest facility and facility counts within 750m radius
- Includes CH4 and CO2 plumes from Carbon Mapper
- Fields: emission rate, plume count, persistence, timestamps

### Attribution Chain

```
Satellite Plume (emissions.sources.geom)
    ↓ ST_DWithin(750m) / spatial query with bbox pre-filter
Infrastructure Facility (infrastructure.all_facilities.geom)
    ↓ Confidence scoring: distance + operator dominance + density
Best Match Selection (type_weight / distance ranking)
    ↓ facility_id, operator, infra_type
Operator Attribution
```

## Key Design Decisions

1. **OGIM v2.7** - Environmental Defense Fund's Oil and Gas Infrastructure Mapping database
2. **GeoPackage format** - SQLite-based spatial database, loaded via DuckDB's SQLite scanner
3. **DuckDB CLI** - No Python dependencies for data loading, pure SQL pipeline
4. **Multi-infrastructure** - Includes wells, compressor stations, processing plants, tank batteries
5. **Type weighting** - Different facility types weighted by emission likelihood
6. **Spatial extension** - GEOMETRY columns for efficient spatial queries
7. **Confidence scoring** - Three-factor scoring system handles attribution ambiguity

## File Structure

```
data/
  OGIM_v2.7.gpkg                      # OGIM infrastructure database (2.9 GB, auto-downloaded via curl)
  sources.json                        # Carbon Mapper emissions GeoJSON (auto-fetched via curl)
  supply-contracts-gemini-2-5-pro.csv # LNG feedgas supply agreements from DOE
  data.duckdb                         # Final database (gitignored)

queries/
  schema.sql                          # Database schema (loads spatial extension)
  load_ogim.sql                       # Load infrastructure from OGIM GeoPackage
  load_emissions.sql                  # Load emissions data (creates geometry)
  create_ogim_attribution.sql         # Multi-infrastructure attribution with confidence scoring
  ogim_lng_attribution.sql            # Match attributed plumes to LNG supply contracts
  create_ogim_attribution_test.sql    # Test version (10 emissions only)

output/
  lng_attribution.csv                 # CH4 plumes matched to LNG feedgas suppliers (52 rows)
```

## Important Implementation Details

### OGIM Data Structure

OGIM v2.7 is a GeoPackage (SQLite-based spatial database) with separate tables for each facility type. The database is automatically downloaded from Zenodo (https://zenodo.org/records/15103476) on first run.

Key tables for Texas and Louisiana:

- **Oil_and_Natural_Gas_Wells**: 970K wells with FAC_ID, OPERATOR, FAC_TYPE, FAC_STATUS, LATITUDE, LONGITUDE
- **Gathering_and_Processing**: 176 facilities with OGIM_ID, OPERATOR, FAC_TYPE
- **Natural_Gas_Compressor_Stations**: 561 facilities with OGIM_ID, OPERATOR, FAC_STATUS
- **Tank_Battery**: 24 facilities with OGIM_ID, OPERATOR, FAC_TYPE

All facilities include OPERATOR field (operator name, not a numeric ID).

### Infrastructure Type Weighting

Different infrastructure types have different emission likelihoods:

- **Processing plants** (2.0x): Highest emission risk due to complex operations, large gas volumes
- **Compressor stations** (1.5x): High risk due to mechanical compression, fugitive emissions
- **Tank batteries** (1.3x): Medium-high risk from venting, flashing
- **Wells** (1.0x): Baseline risk, most numerous facility type

Type weight is used in final facility ranking: `type_weight / (distance + 0.01)` DESC

### Confidence Scoring

Three-factor scoring system (0-100 total):

1. **Distance Score (0-35 points)**: Type-weighted distance score
   - Formula: `(distance_score * type_weight) = GREATEST(0, 35 * (1 - distance_km/0.75)) * type_weight`
   - Closer facilities score higher
   - Weighted by infrastructure type

2. **Operator Dominance Score (0-50 points)**:
   - Formula: `50 * (operator_facilities_of_type / total_facilities_within_750m)`
   - 100% = operator owns all nearby facilities of matched type (50 points)
   - 50% = operator owns half of nearby facilities (25 points)
   - Helps identify contested vs. clear attributions

3. **Density Score (5-15 points)**:
   - 1 facility: 15 points (unambiguous)
   - 2-3 facilities: 12 points
   - 4-10 facilities: 9 points
   - 11-30 facilities: 6 points
   - 30+ facilities: 5 points (highly contested)

### Spatial Query Optimization

Attribution query uses two-stage filtering for performance:

1. **Bounding box pre-filter**: Quickly eliminate most facilities using coordinate ranges
   ```sql
   WHERE ST_X(f.geom) BETWEEN ST_X(e.geom) - 0.0075 AND ST_X(e.geom) + 0.0075
     AND ST_Y(f.geom) BETWEEN ST_Y(e.geom) - 0.0075 AND ST_Y(e.geom) + 0.0075
   ```

2. **Precise distance filter**: ST_DWithin for exact 750m radius
   ```sql
   AND ST_DWithin(e.geom, f.geom, 0.0075)  -- ~750m in degrees
   ```

This two-stage approach is much faster than ST_Distance comparisons alone.

### Geometry Columns

Both infrastructure and emissions use PostGIS-style GEOMETRY columns for spatial queries:

```sql
-- Infrastructure geometry (created in load_ogim.sql)
ST_Point(LONGITUDE, LATITUDE) AS geom

-- Emission geometry (created in load_emissions.sql)
ST_Point(longitude, latitude) AS geom

-- Example: Find nearest facility to an emission
SELECT
    e.id as emission_id,
    f.facility_id,
    f.infra_type,
    f.operator,
    ST_Distance(e.geom, f.geom) * 111 as distance_km
FROM emissions.sources e
CROSS JOIN infrastructure.all_facilities f
WHERE ST_DWithin(e.geom, f.geom, 0.01)  -- ~1km
ORDER BY ST_Distance(e.geom, f.geom)
LIMIT 1;
```

## Common Queries

### Find emissions near facilities operated by a specific company

```sql
-- Install and load spatial extension first
INSTALL spatial;
LOAD spatial;

-- Find emissions within 5km of company's facilities
WITH company_facilities AS (
    SELECT geom, facility_id, infra_type, operator
    FROM infrastructure.all_facilities
    WHERE UPPER(operator) LIKE '%COMPANY_NAME%'
      AND geom IS NOT NULL
)
SELECT
    e.id,
    e.emission_auto as kg_per_hr,
    e.plume_count,
    ST_Y(e.geom) as lat,
    ST_X(e.geom) as lon,
    f.facility_id,
    f.infra_type,
    f.operator,
    ROUND(ST_Distance(e.geom, f.geom) * 111, 2) as distance_km
FROM emissions.sources e
JOIN company_facilities f ON ST_DWithin(e.geom, f.geom, 0.05)  -- ~5km
WHERE e.gas = 'CH4'
ORDER BY e.emission_auto DESC, distance_km;
```

### Find all facilities near a specific plume

```sql
SELECT
    f.facility_id,
    f.infra_type,
    f.operator,
    f.facility_subtype,
    ST_Distance(e.geom, f.geom) * 111 as distance_km
FROM emissions.sources e
JOIN infrastructure.all_facilities f ON ST_DWithin(e.geom, f.geom, 0.01)  -- ~1km
WHERE e.id = 'CH4_1B2_250m_-99.45098_28.43460'
  AND f.geom IS NOT NULL
ORDER BY distance_km;
```

### Show attribution confidence distribution

```sql
SELECT
    CASE
        WHEN confidence_score >= 80 THEN '80-100 (High)'
        WHEN confidence_score >= 60 THEN '60-79 (Medium-High)'
        WHEN confidence_score >= 40 THEN '40-59 (Medium)'
        ELSE 'Under 40 (Low)'
    END as confidence_range,
    COUNT(*) as plume_count,
    ROUND(AVG(distance_to_nearest_facility_km), 2) as avg_distance_km,
    ROUND(AVG(total_facilities_within_750m), 1) as avg_facility_density
FROM emissions.attributed
GROUP BY confidence_range
ORDER BY MIN(confidence_score) DESC;
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
   - Spatial join matches CH4 plumes to nearest infrastructure within 750m
   - Includes operator names directly from OGIM
   - Confidence score (22-92) based on distance, operator dominance, and facility density

2. **LNG Contract Matching** (`ogim_lng_attribution.sql`):
   - Fuzzy string matching (Jaro-Winkler > 0.85) between:
     - Facility operators ↔ LNG contract sellers
   - Matches both producers (Apache, Pioneer) and marketers (Chevron, Enterprise)
   - One row per emission source with aggregated LNG supplier info

### Output Format

`output/lng_attribution.csv` contains:
- Plume details (ID, location, emission rates, timestamps)
- Attribution (nearest facility, operator, infrastructure type, confidence score)
- LNG matches (sellers, projects)

## Database Schema Reference

Full schema definitions with field descriptions are in:
- `queries/schema.sql` - Complete DDL with all tables and columns
- OGIM v2.7 documentation: https://data.catalyst.coop/edf-ogim
- OGIM v2.7 download: https://zenodo.org/records/15103476 (auto-downloaded by `make`)

To explore the schema interactively:
```bash
duckdb data/data.duckdb
D DESCRIBE infrastructure.all_facilities;  # Show infrastructure table
D DESCRIBE emissions.sources;              # Show emissions table
D DESCRIBE emissions.attributed;           # Show attribution results
```

## Future Work

- Add temporal analysis (track facility status changes over time)
- Include other states beyond Texas and Louisiana (OGIM covers multiple states)
- Export to GeoJSON/Shapefile for GIS tools
- Add regular emissions data updates from Carbon Mapper API
- Integrate pipeline data from OGIM (currently only stationary facilities)

## Development Guidelines

- **Minimal dependencies** - Pure make/curl/DuckDB pipeline, no Python required
- **File-based Makefile targets** - Use actual file targets instead of .PHONY where possible
- **Scripts output to stdout** - Redirect to files in Makefile using built-in variables ($@, $<, etc.)
- **DuckDB CLI for pipelines** - No Python/language bindings needed
- **No unnecessary files** - Keep repo clean
- **Document data quality issues** - Note OGIM data limitations (e.g., plugged wells can still emit)
- When editing computationally expensive SQL queries, always add a LIMIT clause in a sensible place to make it run faster during testing, then remove it for production. This saves a lot of waiting around.
