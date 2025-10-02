# Nom de plume

Methane plume attribution system for Texas and Louisiana oil and gas infrastructure.

## Quick Start

```bash
make                    # Build database and generate LNG attribution report
make attribution        # Regenerate attribution table only
make lng-attribution    # Regenerate LNG report only
make clean             # Remove generated files (keep source data)
make clean-all         # Remove everything including source data
```

## Project Overview

**Goal**: Attribute satellite-detected methane plumes to oil and gas operators and LNG export facilities.

**Current State**: Production-ready with 2,661 plumes attributed to infrastructure operators, 91 matched to LNG supply contracts.

**Data**:
- 2,947 CH4 plumes from Carbon Mapper (2025 data, Texas + Louisiana)
- 1.1M+ facilities from OGIM v2.7 and Texas RRC
- LNG supply contracts from DOE filings

## Architecture

### Pipeline

```
OGIM GeoPackage + Carbon Mapper API + Texas RRC data
                  ↓
         DuckDB (data.duckdb)
                  ↓
    Spatial join + confidence scoring
                  ↓
      LNG contract matching
                  ↓
     output/lng_attribution.csv
```

### Database Schema

**Infrastructure** (`infrastructure.all_facilities`):
- 1.1M+ facilities with unified schema
- Types: wells, compressor stations, processing plants, tank batteries
- Source: OGIM v2.7 + Texas RRC (with hybrid operator attribution)
- Fields: `facility_id`, `infra_type`, `type_weight`, `operator`, `facility_subtype`, `status`, `latitude`, `longitude`, `geom`

**Emissions** (`emissions.sources`):
- 2,947 CH4 plumes from Carbon Mapper
- Fields: `id`, `emission_auto` (kg/hr), `plume_count`, `persistence`, `latitude`, `longitude`, `geom`

**Attribution** (`emissions.attributed`):
- 2,661 plumes matched to infrastructure (90% attribution rate)
- Confidence scores (0-100) based on distance, operator dominance, and facility density
- Fields: `emission_id`, `nearest_facility_id`, `operator`, `infra_type`, `confidence_score`, `distance_to_nearest_facility_km`, `total_facilities_within_750m`, `operator_facilities_of_type`

### Hybrid Texas RRC + OGIM Attribution

The system uses a **hybrid approach** combining Texas RRC operator data with OGIM infrastructure:

1. **Wells**: Use Texas RRC P-4 purchaser/gatherer data (more current) instead of OGIM operator field
2. **Other infrastructure**: Use OGIM operator field (compressors, processing plants, tank batteries)

This provides more accurate operator attribution for wells while maintaining comprehensive infrastructure coverage.

### Confidence Scoring

Three-factor scoring system (0-100):

1. **Distance Score (0-35 points, type-weighted)**:
   - Formula: `GREATEST(0, 35 * (1 - distance_km/0.75)) * type_weight`
   - Closer facilities score higher
   - Weighted by infrastructure type (processing=2.0x, compressor=1.5x, tank=1.3x, well=1.0x)

2. **Operator Dominance (0-50 points)**:
   - Formula: `50 * (operator_facilities_of_type / total_facilities_within_750m)`
   - Higher when operator owns most nearby facilities of matched type

3. **Facility Density (5-15 points)**:
   - 1 facility: 15 pts (unambiguous)
   - 2-3: 12 pts, 4-10: 9 pts, 11-30: 6 pts, 30+: 5 pts

### LNG Supply Chain Matching

Matches facility operators to LNG contract sellers using fuzzy string matching (Jaro-Winkler > 0.85).

Chain: `Plume → Infrastructure → Operator → LNG Seller → LNG Facility`

## File Structure

```
data/
  OGIM_v2.7.gpkg           # OGIM infrastructure (auto-downloaded, 2.9 GB)
  sources.json             # Carbon Mapper emissions (auto-fetched, ~13 MB)
  supply-contracts-*.csv   # LNG supply contracts (DOE)
  p4f606.ebc.gz            # Texas RRC P-4 (manual download)
  orf850.ebc.gz            # Texas RRC P-5 (manual download)
  dbf900.ebc.gz            # Texas RRC wellbore (manual download)
  data.duckdb              # Final database (gitignored)

queries/
  schema.sql               # Database schema
  load_emissions.sql       # Load Carbon Mapper data
  load_ogim.sql            # Load OGIM infrastructure
  load_p4.sql              # Load Texas RRC P-4
  load_p5.sql              # Load Texas RRC P-5
  load_wellbore.sql        # Load Texas RRC wellbore
  create_attribution.sql   # Create attribution table
  generate_output.sql      # Generate LNG attribution CSV

scripts/
  create_p4_db.py          # Parse P-4 EBCDIC to /tmp CSVs
  parse_p4.py
  create_p5_db.py          # Parse P-5 EBCDIC to /tmp CSVs
  parse_p5.py
  create_wellbore_db.py    # Parse wellbore EBCDIC to /tmp CSVs
  parse_wellbore.py

output/
  lng_attribution.csv      # Final output (91 plumes with LNG matches)
```

## Common Queries

### Find emissions near a specific operator

```sql
INSTALL spatial; LOAD spatial;

WITH operator_facilities AS (
    SELECT geom, facility_id, infra_type, operator
    FROM infrastructure.all_facilities
    WHERE UPPER(operator) LIKE '%COMPANY%'
)
SELECT
    e.id,
    e.emission_auto as kg_per_hr,
    f.facility_id,
    f.infra_type,
    f.operator,
    ROUND(ST_Distance(e.geom, f.geom) * 111, 2) as distance_km
FROM emissions.sources e
JOIN operator_facilities f ON ST_DWithin(e.geom, f.geom, 0.05)
WHERE e.gas = 'CH4'
ORDER BY e.emission_auto DESC, distance_km;
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
    ROUND(AVG(distance_to_nearest_facility_km), 2) as avg_distance_km
FROM emissions.attributed
GROUP BY confidence_range
ORDER BY MIN(confidence_score) DESC;
```

## Development Guidelines

- **Use uv for Python**: All Python scripts use uv (specified in global CLAUDE.md)
- **File-based Makefile targets**: Use actual file targets instead of .PHONY where possible
- **Scripts output to stdout**: Redirect to files in Makefile using built-in variables
- **Test with LIMIT**: When editing expensive SQL queries, add LIMIT during testing
- **Keep repo clean**: Parse Texas RRC data to /tmp, not the repo
- **DuckDB CLI for pipelines**: No Python/language bindings needed for data loading

## Key Implementation Details

### Spatial Query Optimization

Attribution uses two-stage filtering:

1. **Bounding box pre-filter**: Quickly eliminate facilities using coordinate ranges
2. **ST_DWithin**: Precise 750m radius check

This is much faster than naive ST_Distance comparisons on 1M+ facilities.

### Texas RRC Data Integration

RRC data files (p4f606.ebc.gz, orf850.ebc.gz, dbf900.ebc.gz) are EBCDIC-encoded binary files that must be:
1. Downloaded manually from https://mft.rrc.texas.gov/
2. Parsed by Python scripts to /tmp/*.csv
3. Loaded into DuckDB

The P-4 "purchaser" field is used as the operator for wells, providing more current attribution than OGIM.

## Data Sources

- **OGIM v2.7**: https://zenodo.org/records/15103476 (auto-downloaded)
- **Carbon Mapper**: https://api.carbonmapper.org/api/v1/catalog/sources.geojson (auto-fetched)
- **Texas RRC**: https://mft.rrc.texas.gov/ (manual download required)
- **DOE LNG Contracts**: data/supply-contracts-gemini-2-5-pro.csv (parsed by Gemini 2.5 Pro)

## Future Work

- Add Louisiana RRC data for Louisiana wells
- Temporal analysis (track facility status changes)
- Export to GeoJSON/Shapefile
- Regular emissions data updates from Carbon Mapper API
- Pipeline infrastructure from OGIM
