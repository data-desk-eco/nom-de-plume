# Nom de Plume

**Methane plume attribution system for Texas and Louisiana LNG supply chains**

This pipeline connects satellite-detected methane emissions to specific oil and gas operators and LNG export facilities, revealing which companies' infrastructure is leaking methane that feeds liquefied natural gas exports.

## What This Does

1. **Loads infrastructure data** from OGIM v2.7 (Environmental Defense Fund's Oil & Gas Infrastructure Mapping) and Texas Railroad Commission
2. **Loads satellite methane observations** from Carbon Mapper's Tanager-1 satellite
3. **Matches plumes to infrastructure** using spatial queries (wells, compressors, processing plants, tank batteries within 750m)
4. **Attributes to operators** using hybrid Texas RRC + OGIM data with confidence scoring
5. **Links to LNG supply chains** by matching operators to DOE-filed LNG feedgas contracts

The result: A dataset showing which CH4 emissions are connected to which LNG export facilities (Sabine Pass, Corpus Christi, Freeport, etc.).

## Key Outputs

- **2,661 methane plumes** (2025 data) attributed to infrastructure operators (90% attribution rate)
- **91 plumes** matched to LNG supply contracts
- Each plume includes:
  - Emission rate (kg/hr methane)
  - Nearest infrastructure (well, compressor, processing plant, or tank battery)
  - Infrastructure operator (from Texas RRC or OGIM)
  - LNG facility and contract sellers
  - Confidence score (0-100, based on distance, operator dominance, and facility density)
  - Geographic coordinates

## Data Sources

1. **OGIM v2.7** (Environmental Defense Fund)
   - 970K+ Texas and Louisiana wells with operator information
   - 561 compressor stations, 176 gas processing plants, 24 tank batteries
   - Auto-downloaded from Zenodo: https://zenodo.org/records/15103476

2. **Texas Railroad Commission**
   - P-4 Schedule data (purchaser/gatherer information)
   - P-5 Organization data (operator names)
   - Wellbore data (API→lease mappings)
   - Manual download required from: https://mft.rrc.texas.gov/
   - Files: `p4f606.ebc.gz`, `orf850.ebc.gz`, `dbf900.ebc.gz`

3. **Carbon Mapper**
   - Satellite methane plume observations
   - Emission rates and timestamps
   - Auto-fetched via API

4. **US Department of Energy**
   - LNG feedgas supply contracts (parsed by Gemini 2.5 Pro)
   - Stored in `data/supply-contracts-gemini-2-5-pro.csv`

## Prerequisites

- DuckDB CLI (`brew install duckdb`)
- Python 3.x with uv (`curl -LsSf https://astral.sh/uv/install.sh | sh`)
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
# 5. Parses Texas RRC data (P-4, P-5, wellbore) to /tmp (~2 min)
# 6. Creates attribution table with spatial join (~3 min)
# 7. Generates LNG attribution report (~1 sec)
# Total first run: ~11 minutes (subsequent runs: ~6 minutes)
```

Output file:
- `output/lng_attribution.csv` (91 rows, ~28 KB)

### Rebuilding

```bash
# Rebuild database from existing data
make data/data.duckdb

# Re-fetch emissions data (get latest from Carbon Mapper)
rm data/sources.json && make

# Regenerate attribution table only
make attribution

# Regenerate LNG report only
make lng-attribution

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
| `rate_detected_kg_hr` | Emission rate adjusted for persistence |
| `rate_uncertainty_kg_hr` | Uncertainty in emission rate |
| `plume_count` | Number of times plume was observed |
| `timestamp_min/max` | First and last observation dates |
| `latitude/longitude` | Plume center coordinates |
| `nearest_facility_id` | Infrastructure facility identifier |
| `facility_subtype` | Detailed facility type (e.g., "Gas Well", "Gas Plant") |
| `nearest_facility_operator` | Company operating the facility |
| `distance_to_nearest_facility_km` | Distance to matched facility |
| `total_facilities_within_750m` | Number of facilities within 750m radius |
| `operator_facilities_of_type` | Nearby facilities of same type operated by matched operator |
| `confidence_score` | Attribution confidence (0-100) |
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

### Step 2: Hybrid Texas RRC + OGIM Operator Attribution

- **Wells**: Use Texas RRC P-4 purchaser/gatherer data (more current than OGIM)
- **Other infrastructure**: Use OGIM operator field (compressors, processing plants, tank batteries)

This hybrid approach provides more accurate operator attribution for wells while maintaining comprehensive infrastructure coverage.

### Step 3: LNG Supply Chain Matching

Match facility operators to LNG contract sellers using fuzzy string matching (Jaro-Winkler similarity > 0.85).

**Why this matters**: Identifies which LNG export facilities receive gas from leaking infrastructure. Operators include both producers (Apache, Pioneer, EOG) and marketers (Chevron, Enterprise, Kinder Morgan).

## Performance Optimization

The attribution query uses two-stage spatial filtering:

1. **Bounding box pre-filter**: Quickly eliminate facilities outside ~750m using coordinate ranges
2. **Precise distance check**: ST_DWithin for exact 750m radius

This approach is significantly faster than naive ST_Distance comparisons on 1M+ facilities.

## Technical Details

See `CLAUDE.md` for:
- Complete database schema
- OGIM and Texas RRC data structure details
- Confidence scoring formulas
- SQL query examples
- Spatial query optimization techniques

## License

Data sources are public records. Analysis code and methods are provided for transparency and reproducibility in climate journalism.
