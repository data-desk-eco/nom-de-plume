# Nom de Plume

**Methane plume attribution system for Texas and Louisiana LNG supply chains**

This pipeline connects satellite-detected methane emissions to specific oil and gas operators and LNG export facilities, revealing which companies' infrastructure is leaking methane that feeds liquefied natural gas exports.

## What This Does

1. **Loads infrastructure data** from OGIM v2.7 (Environmental Defense Fund's Oil & Gas Infrastructure Mapping)
2. **Loads satellite methane observations** from Carbon Mapper's Tanager-1 satellite
3. **Matches plumes to infrastructure** using spatial queries (wells, compressors, processing plants, tank batteries within 750m)
4. **Attributes to operators** using multi-infrastructure confidence scoring
5. **Links to LNG supply chains** by matching operators to DOE-filed LNG feedgas contracts

The result: A dataset showing which CH4 emissions are connected to which LNG export facilities (Sabine Pass, Corpus Christi, Freeport, etc.).

## Key Outputs

- **290 methane plumes** (2025 data) attributed to infrastructure operators
- **52 plumes** matched to LNG supply contracts
- Each plume includes:
  - Emission rate (kg/hr methane)
  - Nearest infrastructure (well, compressor, processing plant, or tank battery)
  - Infrastructure operator
  - LNG facility and contract sellers
  - Confidence score (22-92, based on distance, operator dominance, and facility density)
  - Geographic coordinates

## Data Sources

1. **OGIM v2.7** (Environmental Defense Fund)
   - 970K+ Texas and Louisiana wells with operator information
   - 561 compressor stations
   - 176 gas processing plants
   - 24 tank batteries
   - Auto-downloaded from Zenodo: https://zenodo.org/records/15103476

2. **Carbon Mapper**
   - Satellite methane plume observations
   - Emission rates and timestamps
   - Fetched via API: `uv run scripts/fetch_emissions.py`

3. **US Department of Energy**
   - LNG feedgas supply contracts (parsed by Gemini 2.5 Pro)
   - Stored in `data/supply-contracts-gemini-2-5-pro.csv`

## Prerequisites

- DuckDB CLI (`brew install duckdb`)
- Make
- curl (standard on macOS/Linux)

## Running the Pipeline

Everything is fully automated - just run `make`:

```bash
# Build complete pipeline and generate LNG attribution report
make

# First run automatically:
# 1. Downloads OGIM v2.7 from Zenodo (~2.9 GB, one-time, ~5 min)
# 2. Fetches emissions from Carbon Mapper API (~10K sources, ~13 MB, <10 sec)
# 3. Loads infrastructure from OGIM GeoPackage (~30 sec)
# 4. Loads emissions data (~5 sec)
# 5. Creates attribution table with spatial join (~3 min)
# 6. Generates LNG attribution report (~1 sec)
# Total first run: ~9 minutes (subsequent runs: ~4 minutes)
```

Output file:
- `output/lng_attribution.csv` (52 rows, ~28 KB)

### Rebuilding

```bash
# Rebuild database from existing data
make data/data.duckdb

# Re-fetch emissions data (get latest from Carbon Mapper)
rm data/sources.json && make

# Clean generated files (keeps downloaded source data)
make clean

# Clean everything including source data (will re-download on next make)
make clean-all
```

## Output Format

The LNG attribution CSV contains one row per emission source with:

| Column | Description |
|--------|-------------|
| `id` | Unique emission source identifier |
| `rate_avg_kg_hr` | Average methane emission rate (kg/hr) |
| `rate_detected_kg_hr` | Emission rate adjusted for persistence (avg/persistence) |
| `rate_uncertainty_kg_hr` | Uncertainty in emission rate |
| `plume_count` | Number of times plume was observed |
| `timestamp_min/max` | First and last observation dates |
| `latitude/longitude` | Plume center coordinates |
| `nearest_facility_id` | Infrastructure facility identifier |
| `facility_subtype` | Detailed facility type (e.g., "Gas Well", "Gas Plant") |
| `nearest_facility_operator` | Company operating the facility |
| `distance_to_nearest_facility_km` | Distance to matched facility |
| `total_facilities_within_750m` | Number of facilities within 750m radius |
| `operator_facilities_of_type` | Number of nearby facilities of same type operated by matched operator |
| `confidence_score` | Attribution confidence (22-92) |
| `lng_sellers` | Matched LNG contract sellers with similarity scores |
| `lng_projects` | LNG facilities (Sabine Pass, Corpus Christi, etc.) |

## How Attribution Works

### Step 1: Plume → Infrastructure Matching

For each CH4 plume, find all infrastructure within 750m radius (wells, compressor stations, processing plants, tank batteries).

**Infrastructure Type Weighting**:
- Processing plants (2.0x): Highest emission risk
- Compressor stations (1.5x): High risk
- Tank batteries (1.3x): Medium-high risk
- Wells (1.0x): Baseline risk

**Best Match Selection**: Rank by `type_weight / (distance + 0.01)` and select the top facility.

**Confidence Score** (0-100) based on:
- **Distance Score** (0-35 points, type-weighted): Closer facilities score higher (35 pts at 0m, 0 pts at 750m)
- **Operator Dominance** (0-50 points): % of nearby facilities of same type operated by matched operator
- **Facility Density** (5-15 points): Fewer facilities = less ambiguity = higher score

### Step 2: LNG Supply Chain Matching

Match facility operators to LNG contract sellers using fuzzy string matching (Jaro-Winkler similarity > 0.85).

**Why this matters**: Identifies which LNG export facilities receive gas from leaking infrastructure. Operators include both producers (Apache, Pioneer, EOG) and marketers (Chevron, Enterprise, Kinder Morgan).

## Performance Optimization

The attribution query uses two-stage spatial filtering:

1. **Bounding box pre-filter**: Quickly eliminate facilities outside ~750m using coordinate ranges
2. **Precise distance check**: ST_DWithin for exact 750m radius

This approach is significantly faster than naive ST_Distance comparisons on 970K+ facilities.

## Technical Details

See `CLAUDE.md` for:
- Complete database schema
- OGIM data structure details
- Confidence scoring formulas
- SQL query examples
- Spatial query optimization techniques

## Methodology

See `METHODOLOGY.md` for the research approach and validation methodology.

## License

Data sources are public records. Analysis code and methods are provided for transparency and reproducibility in climate journalism.
