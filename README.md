# Nom de Plume

**Methane plume attribution system for Texas LNG supply chains**

This pipeline connects satellite-detected methane emissions to specific oil and gas operators and LNG export facilities, revealing which companies' infrastructure is leaking methane that feeds liquefied natural gas exports.

## What This Does

1. **Parses Texas oil and gas well data** from Railroad Commission EBCDIC files (1M+ wells)
2. **Loads satellite methane observations** from Carbon Mapper's Tanager-1 satellite
3. **Matches plumes to wells** using spatial queries (within 500m radius)
4. **Attributes to operators and gas purchasers** via lease and contract data
5. **Links to LNG supply chains** by matching operators/purchasers to DOE-filed LNG feedgas contracts

The result: A dataset showing which CH4 emissions are connected to which LNG export facilities (Sabine Pass, Corpus Christi, Freeport, etc.).

## Key Outputs

- **743 methane plumes** matched to LNG supply contracts
- Each plume includes:
  - Emission rate (kg/hr methane)
  - Well operator and gas purchasers
  - LNG facility and contract sellers
  - Confidence score (0-100)
  - Geographic coordinates

## Data Sources

1. **Texas Railroad Commission** (RRC)
   - Well locations and operators (EBCDIC format)
   - Lease data and gas purchase contracts
   - Organization registry

2. **Carbon Mapper**
   - Satellite methane plume observations
   - Emission rates and timestamps

3. **US Department of Energy**
   - LNG feedgas supply contracts (parsed by Gemini 2.5 Pro)
   - Stored in `data/supply-contracts-gemini-2-5-pro.csv`

## Prerequisites

- Python 3.10+ (managed via `uv`)
- DuckDB CLI (`brew install duckdb`)
- Make

## Setup

The pipeline requires large source data files (not in repo):

```bash
# Download RRC data files (place in data/)
# - p4f606.ebc.gz (P-4 lease/producer data, 203 MB)
# - dbf900.ebc.gz (Wellbore database, 487 MB)
# - orf850.ebc.gz (Organization data, 20 MB)
# Available from: https://www.rrc.texas.gov/resource-center/research/data-sets-available-for-download/

# Fetch latest emissions data
uv run scripts/fetch_emissions.py
```

## Running the Pipeline

### Full Build

```bash
# Parse EBCDIC files, load database, create attribution table
make

# This will:
# 1. Convert EBCDIC → CSV (5-10 min)
# 2. Load into DuckDB (~2 min)
# 3. Create spatial indexes (~1 min)
# 4. Run attribution spatial join (~5 min)
```

### Generate LNG Attribution Report

```bash
make lng-attribution
```

Output: `output/lng_attribution.csv` (743 rows, ~286 KB)

## Output Format

The LNG attribution CSV contains one row per emission source with:

| Column | Description |
|--------|-------------|
| `id` | Unique emission source identifier |
| `rate_avg_kg_hr` | Average methane emission rate (kg/hr) |
| `rate_detected_kg_hr` | Rate when detected (accounts for persistence) |
| `plume_count` | Number of times plume was observed |
| `timestamp_min/max` | First and last observation dates |
| `latitude/longitude` | Plume center coordinates |
| `nearest_well_api` | Well identifier (format: county-unique) |
| `nearest_well_operator` | Company operating the well |
| `purchaser_names` | Companies purchasing gas from this lease |
| `distance_to_nearest_well_km` | Distance to matched well |
| `confidence_score` | Attribution confidence (0-100) |
| `lng_sellers` | Matched LNG contract sellers with similarity scores |
| `lng_projects` | LNG facilities (Sabine Pass, Corpus Christi, etc.) |
| `lng_match_count` | Number of distinct LNG suppliers matched |

## How Attribution Works

### Step 1: Plume → Well Matching

For each CH4 plume, find all wells within 500m radius and identify the nearest well.

**Confidence Score** (0-100) based on:
- **Operator Dominance** (0-50 points): Higher if matched operator controls most nearby wells
- **Distance** (0-35 points): Higher for closer wells (35 points at 0m, 0 points at 500m)
- **Well Density** (5-15 points): Higher when fewer wells nearby (less ambiguity)

### Step 2: LNG Supply Chain Matching

Match operators and gas purchasers to LNG contract sellers using fuzzy string matching (Jaro-Winkler similarity > 0.85).

**Why purchasers matter**: In Texas, many wells are operated by independent producers but the *gas purchasers* (large midstream/marketing companies like Chevron, Enterprise, Kinder Morgan) are the ones with LNG supply contracts. They buy gas at the wellhead, aggregate it, and sell to LNG facilities.

## Technical Details

See `CLAUDE.md` for:
- Database schema and field definitions
- EBCDIC parsing implementation
- SQL query examples
- Data quality notes

## Methodology

See `METHODOLOGY.md` for the research approach and validation methodology.

## License

Data sources are public records. Analysis code and methods are provided for transparency and reproducibility in climate journalism.
