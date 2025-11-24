# Nom de plume

Methane plume attribution system for global oil and gas infrastructure.

This is a Data Desk research notebook built with Observable Notebook Kit 2.0.

## Quick Start

```bash
# LOCAL DEVELOPMENT (infrequent - every few months)
make infrastructure     # Build infrastructure.duckdb (OGIM + Texas RRC)
                       # Upload to GitHub Releases after building

# GITHUB ACTIONS (automatic - daily)
make data              # ETL: Download infra DB → load plumes → run attribution → export JSON
make build             # Build notebook and deploy

# LOCAL TESTING
make preview           # Start local development server
make build             # Build static site for local testing

# UTILITIES
make clean             # Remove generated files (keep source data)
make clean-all         # Remove everything including source data
```

## Project Overview

**Goal**: Attribute satellite-detected methane plumes to oil and gas operators and LNG export facilities.

**Current State**: Production-ready with individual plume observations attributed to infrastructure operators and LNG supply contracts.

**Data**:
- Latest plume observations from Carbon Mapper (updated daily via ETL)
  - Super-emitters: ≥100 kg/hr, ≥75% confidence, ≤500m from facility
  - Historical range: Jan 2025 - present
- 1.1M+ facilities from OGIM v2.7 (global) and Texas RRC (Texas wells)
  - Infrastructure database rebuilt manually every few months

## Architecture

### Two-Stage Pipeline

**Stage 1: Infrastructure Database (Local, Manual - Every few months)**
```
OGIM GeoPackage (2.9 GB) + Texas RRC data (20M+ records)
                  ↓
      Parse EBCDIC files to /tmp CSVs
                  ↓
      Load to infrastructure.duckdb
                  ↓
         Vacuum and optimize
                  ↓
   Compress and upload to GitHub Releases
```
**Command:** `make infrastructure` → upload `infrastructure.duckdb.gz` to releases

**Stage 2: ETL + Notebook Build (GitHub Actions - Daily)**
```
Download infrastructure.duckdb.gz from GitHub Releases
                  ↓
    Download latest plumes (YYYY-01-01 to today)
                  ↓
    Copy infra DB → data.duckdb + load plumes
                  ↓
    Spatial join + confidence scoring
                  ↓
      Export top 500 super-emitters to JSON
          (queries/exports/*.sql → data/*.json)
                  ↓
     Commit data/*.json to repo
                  ↓
     Observable notebook loads ../data/*.json
          (FileAttachment API)
                  ↓
         Build and deploy to GitHub Pages
```
**Command:** `make data` (runs in GitHub Actions)

**Key Benefits:**
- Infrastructure DB: ~500 MB (vs 2.9 GB source), updated quarterly
- ETL: Fast (~2 min), runs daily with latest plumes
- Notebook: Loads pre-computed JSON, no database needed at runtime

### Database Schema

**Infrastructure** (`infrastructure.all_facilities`):
- 1.1M+ facilities with unified schema
- Types: wells, compressor stations, processing plants, tank batteries
- Source: OGIM v2.7 + Texas RRC (with hybrid operator attribution)
- Fields: `facility_id`, `infra_type`, `type_weight`, `operator`, `facility_subtype`, `status`, `latitude`, `longitude`, `geom`

**Emissions** (`emissions.sources`):
- 7,437 plume observations from Carbon Mapper (individual observations, not aggregated)
- Fields: `id`, `emission_auto` (kg/hr), `datetime`, `ipcc_sector`, `latitude`, `longitude`, `geom`, wind data, technical metadata

**Attribution** (`emissions.attributed`):
- Individual plumes matched to infrastructure
- Confidence scores (0-100) based on distance, operator dominance, and facility density
- Fields: `id`, `rate_kg_hr`, `datetime`, `nearest_facility_id`, `entity_name` (operator), `nearest_facility_type`, `confidence_score`, `distance_to_nearest_facility_km`, `total_facilities_nearby`, `operator_facilities_of_type`

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
   - Formula: `50 * (operator_facilities_of_type / total_facilities_within_1.5km)`
   - Higher when operator owns most nearby facilities of matched type

3. **Facility Density (5-15 points)**:
   - 1 facility: 15 pts (unambiguous)
   - 2-3: 12 pts, 4-10: 9 pts, 11-30: 6 pts, 30+: 5 pts

### LNG Supply Chain Matching

Matches facility operators to LNG contract sellers using fuzzy string matching (Jaro-Winkler > 0.85).

Chain: `Plume → Infrastructure → Operator → LNG Seller → LNG Facility`

## File Structure

```
docs/
  index.html               # Observable notebook source (EDIT THIS)
  assets/                  # Images and static assets
  .observable/dist/        # Built output (gitignored, deployed to GitHub Pages)

data/
  plumes.json             # Exported plume data (committed, generated by ETL)
  infrastructure.json     # Exported facility data (committed, generated by ETL)
  infrastructure.duckdb    # Infrastructure-only DB (gitignored, built locally)
  infrastructure.duckdb.gz # Compressed infra DB (uploaded to GitHub Releases)
  data.duckdb             # Working database (gitignored, built in ETL)
  plumes_latest.zip       # Latest plumes from Carbon Mapper (auto-downloaded in ETL)
  plumes_latest.csv       # Extracted plumes data
  OGIM_v2.7.gpkg          # OGIM infrastructure (auto-downloaded, 2.9 GB)
  p4f606.ebc.gz           # Texas RRC P-4 (auto-downloaded)
  orf850.ebc.gz           # Texas RRC P-5 (auto-downloaded)
  dbf900.ebc.gz           # Texas RRC wellbore (auto-downloaded)

queries/
  schema.sql              # Database schema
  load_emissions.sql      # Load Carbon Mapper data
  load_ogim.sql           # Load OGIM infrastructure
  load_p4.sql             # Load Texas RRC P-4
  load_p5.sql             # Load Texas RRC P-5
  load_wellbore.sql       # Load Texas RRC wellbore
  create_attribution.sql  # Create attribution table
  exports/
    plumes.sql           # Export query for plume data
    infrastructure.sql   # Export query for facility data

scripts/
  download_rrc.py         # Download RRC files from MFT via Playwright
  create_p4_db.py         # Parse P-4 EBCDIC to /tmp CSVs
  parse_p4.py
  create_p5_db.py         # Parse P-5 EBCDIC to /tmp CSVs
  parse_p5.py
  create_wellbore_db.py   # Parse wellbore EBCDIC to /tmp CSVs
  parse_wellbore.py

template.html             # HTML wrapper (auto-updates from main repo)
Makefile                  # Build automation
CLAUDE.md                 # This file (auto-updates)
```

## Interactive Visualization

The project includes an Observable Notebook Kit notebook (`docs/index.html`) that provides an interactive exploration of super-emitter events.

**Features**:
- Displays up to 500 most recent super-emitter events (≥100 kg/hr, ≥75 confidence score, ≤500m from facility)
- Expandable cards showing operator, facility type, emission rate, observation date, and confidence score
- Interactive maps with grayscale satellite imagery showing plume locations and nearby infrastructure
- Color-coded facility markers by type (wells, compressors, processing plants, etc.)
- Facility counts distinguishing operator-owned vs. total nearby facilities
- Direct links to plume detail pages on Carbon Mapper's data portal

**Usage**:
```bash
make preview    # Start development server (http://localhost:3000)
make build      # Compile to static site
```

**Technical Details**:
- Loads pre-computed data from `../data/plumes.json` and `../data/infrastructure.json`
- Data files committed to repo in `data/` directory (generated by ETL pipeline)
- Pre-loads infrastructure within 1.5km of each plume for map display
- Uses Leaflet.js for interactive maps with Esri World Imagery tiles
- Responsive design: side-by-side layout on desktop, stacked on mobile
- Color palette: Red (#D94848), Orange (#F28322), Yellow (#F1C644), Green (#60BF66), Purple (#9461C7)

**Data Consistency Note**: Map facility counts may differ from attribution table totals if data has been updated since attribution calculation. Run `make attribution` to regenerate with current data.

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
    ROUND(ST_Distance_Sphere(e.geom, f.geom) / 1000.0, 2) as distance_km
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
- **Two-stage architecture**: Infrastructure DB built locally (infrequent), ETL runs in CI (frequent)
- **Commit JSON exports**: `data/*.json` files committed to repo for notebook (use `!data/*.json` in .gitignore)
- **SQL in files**: Export queries in `queries/exports/*.sql`, not inline in Makefile
- **File-based Makefile targets**: Use actual file targets instead of .PHONY where possible
- **Keep repo clean**: Parse Texas RRC data to `/tmp`, not the repo
- **DuckDB CLI for pipelines**: No Python/language bindings needed for data loading
- **GitHub Releases**: Upload `infrastructure.duckdb.gz` to GitHub Releases after building locally

## Workflow

### Initial Setup (One-time)

1. **Build infrastructure database locally**:
   ```bash
   make infrastructure  # Downloads OGIM + RRC data, builds infrastructure.duckdb
   ```

2. **Upload to GitHub Releases**:
   ```bash
   gzip data/infrastructure.duckdb
   gh release create v1.0 data/infrastructure.duckdb.gz \
     --title "Infrastructure Database v1.0" \
     --notes "OGIM v2.7 + Texas RRC data ($(date +%Y-%m-%d))"
   ```

3. **Enable GitHub Pages**: Settings → Pages → Source: GitHub Actions

### Ongoing Updates (Automatic)

- **Daily**: GitHub Actions runs `make data` to update plumes
- **Quarterly**: Rebuild infrastructure DB locally and upload new release
- **As needed**: Update queries in `queries/exports/*.sql` for different data exports

**Note**: Notebook loads from `../data/*.json` (relative to `docs/index.html`), following standard Data Desk pattern.

## Key Implementation Details

### Spatial Query Optimization

Attribution uses two-stage filtering:

1. **Bounding box pre-filter**: Quickly eliminate facilities using coordinate ranges (±0.015°)
2. **ST_DWithin**: Precise 1.5km radius check using spherical distance calculations

This is much faster than naive ST_Distance comparisons on 1M+ facilities.

**Distance Calculation**: Uses `ST_Distance_Sphere()` which returns meters on a sphere (WGS84), avoiding the latitude-dependent errors from simple degree-to-km conversions.

### Texas RRC Data Integration

RRC data files (p4f606.ebc.gz, orf850.ebc.gz, dbf900.ebc.gz) are EBCDIC-encoded binary files that are:
1. Auto-downloaded from https://mft.rrc.texas.gov/ via Playwright
2. Parsed by Python scripts to /tmp/*.csv
3. Loaded into DuckDB

The P-4 "purchaser" field is used as the operator for wells, providing more current attribution than OGIM.

## Data Sources

- **OGIM v2.7**: https://zenodo.org/records/15103476 (auto-downloaded)
- **Carbon Mapper Plumes**: https://s3.us-west-1.amazonaws.com/msf.data/exports/plumes_2025-01-01_2025-10-01.zip (auto-downloaded)
- **Texas RRC**: https://mft.rrc.texas.gov/ (auto-downloaded via Playwright)
- **DOE LNG Contracts**: data/supply-contracts-gemini-2-5-pro.csv (parsed by Gemini 2.5 Pro)

## Future Work

- Add Louisiana RRC data for Louisiana wells
- Temporal analysis (track facility status changes over multiple observations)
- Aggregate multiple observations of the same source/facility
- Export to GeoJSON/Shapefile
- Regular emissions data updates from Carbon Mapper
- Pipeline infrastructure from OGIM
- Support for additional plume metadata (wind data, uncertainty, technical parameters)
