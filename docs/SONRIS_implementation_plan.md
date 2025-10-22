# SONRIS Implementation Plan: Well-Level Operator Data

## Executive Summary

The current SONRIS integration (Form R5T) provides **transporter flow data at the field level**, which is useful supplementary information but **NOT equivalent to Texas RRC P-4 purchaser/gatherer data**.

For true parity with the Texas attribution pipeline, we need to integrate **SONRIS well-level operator data**, which contains current operator information for individual Louisiana wells.

## Current State

### What We Have: R5T Transporter Flow Data ✓

**SONRIS Form R5T** tracks natural gas flows between entities:
- **79 operators/gatherers** across **105 fields** (highly aggregated)
- **11 transporters** filing monthly reports
- Flow volumes: operator/gatherer → transporter → processing plant
- **Purpose**: Pipeline regulatory tracking (interstate/intrastate flows)
- **Granularity**: Field-level (not well-level)

**Use case**: Understanding transporter relationships and field-level gas movements.

### What We're Missing: Well-Level Operator Data ❌

**SONRIS Well Database** contains:
- **Current Operator** for each individual well
- **Well Serial Number** (Louisiana's unique identifier)
- **API Number** (standardized well identifier)
- Well locations (Latitude/Longitude, Lambert coordinates)
- Well status, dates, field assignments
- **Granularity**: Individual well level

**Use case**: Attributing methane plumes to specific well operators (the core mission).

## The Data Gap

### Texas Pipeline (Complete)

```
┌─────────────────┐
│ Wellbore DB     │  API → Well Location
│ (dbf900.ebc.gz) │
└─────────────────┘
         ↓
┌─────────────────┐
│ P-4 Data        │  Well → Purchaser/Gatherer
│ (p4f606.ebc.gz) │  (Current operator via lease)
└─────────────────┘
         ↓
┌─────────────────┐
│ P-5 Data        │  Operator Number → Operator Name
│ (orf850.ebc.gz) │
└─────────────────┘
         ↓
  Attribution: Well-level operator for each Texas well
```

### Louisiana Pipeline (Incomplete)

```
┌─────────────────┐
│ OGIM Wells      │  Well locations + OGIM operator field
│                 │  ⚠️  Operator data may be outdated
└─────────────────┘
         ↓
┌─────────────────┐
│ R5T Data        │  Field-level transporter flows
│ (Current)       │  ⚠️  Too aggregated for well attribution
└─────────────────┘
         ↓
  Attribution: OGIM operator (potentially stale)

┌─────────────────┐
│ SONRIS Well DB  │  Serial/API → Current Operator
│ (NEEDED!)       │  ✓  Most current operator data
└─────────────────┘
         ↓
  Attribution: Current operator for each Louisiana well
```

## Available SONRIS Well Data

### Data Fields (from search results)

According to Louisiana DNR documentation, SONRIS well downloads include:

**Identifiers:**
- Well Serial Number (Louisiana-specific)
- Well Name
- Well Number
- API Number

**Operator Information:**
- **Current Operator** ⭐ (This is what we need!)
- Operator changes over time (historical)

**Location Data:**
- Parish Code and Name
- Field Code and Name
- Section, Township, Range
- Lambert Coordinates (Louisiana State Plane)
- Latitude and Longitude (WGS84)

**Well Details:**
- Well Status and Date
- Permit Date, Spud Date, Original Completion Date
- Last Perforation Date
- Current LUW Code (lease unit well)
- Primary Product
- Measured and Bottom Hole Depths
- Last Three Perforations and Producing Sand
- Comments

**Production:**
- Monthly LUW Production (from inception)
- Annual Field Production

### Data Access Methods

**Option 1: GIS Download (Bulk)**
- URL: http://sonris-gis.dnr.state.la.us/website/DownloadLogin.html
- Format: Likely shapefile or CSV
- Update frequency: Daily updates according to documentation
- **Status**: Requires account/authentication (403 error on web fetch)

**Option 2: Interactive Data Reports (IDR)**
- URL: Available through SONRIS portal at https://sonris.com/
- Format: Exportable to Excel/CSV
- Allows custom queries with filters
- **Status**: Requires manual web interface interaction

**Option 3: Individual Well Lookup**
- URL: https://sonlite.dnr.state.la.us/sundown/cart_prod/cart_con_wellinfo1
- Format: HTML forms, individual well queries
- **Status**: Not suitable for bulk downloads

**Option 4: Contact DNR Directly**
- Contact: Beverly Kahl at (225) 342-4618 or Beverly.kahl@la.gov
- May provide bulk data access or API access
- **Status**: Not yet contacted

## Recommended Implementation

### Phase 1: Data Acquisition Research

1. **Test GIS Download Portal**
   - Create account at SONRIS GIS download site
   - Document available file formats (shapefile, CSV, geodatabase)
   - Assess data completeness and update frequency
   - Download sample data for schema analysis

2. **Test Interactive Data Reports**
   - Access SONRIS IDR system
   - Identify query parameters for bulk well data export
   - Test Excel export functionality
   - Assess automation potential (Selenium if needed)

3. **Contact Louisiana DNR**
   - Request information about bulk data access
   - Ask about API access or FTP/direct download options
   - Inquire about data refresh schedule
   - Clarify licensing and usage terms

### Phase 2: Data Integration (Once Source Identified)

**Schema Design:**
```sql
DROP SCHEMA IF EXISTS sonris_wells CASCADE;
CREATE SCHEMA sonris_wells;

CREATE TABLE sonris_wells.wells (
  -- Identifiers
  serial_number VARCHAR NOT NULL,          -- Louisiana well serial number
  api_number VARCHAR,                      -- API number (for cross-reference)
  well_name VARCHAR,
  well_number VARCHAR,

  -- Current operator (KEY FIELD for attribution)
  current_operator VARCHAR NOT NULL,
  operator_number VARCHAR,                 -- If available

  -- Location
  parish_code VARCHAR,
  parish_name VARCHAR,
  field_code VARCHAR,
  field_name VARCHAR,
  latitude DOUBLE,
  longitude DOUBLE,
  geom GEOMETRY,                           -- Point geometry

  -- Status
  well_status VARCHAR,
  status_date DATE,
  primary_product VARCHAR,                 -- Oil, Gas, etc.

  -- Dates
  permit_date DATE,
  spud_date DATE,
  completion_date DATE,

  -- Metadata
  comments VARCHAR,
  last_updated DATE
);
```

**Integration Points:**

1. **Supplement OGIM wells** with current operator from SONRIS
   ```sql
   -- Enhanced Louisiana well attribution
   SELECT
     ogim.facility_id,
     ogim.latitude,
     ogim.longitude,
     COALESCE(sonris.current_operator, ogim.operator) as operator,
     'sonris' as operator_source
   FROM infrastructure.all_facilities ogim
   LEFT JOIN sonris_wells.wells sonris
     ON ogim.state_prov = 'LOUISIANA'
     AND (ogim.api_number = sonris.api_number
          OR ST_DWithin(ogim.geom, sonris.geom, 0.0001))
   WHERE ogim.infra_type = 'well'
   ```

2. **Create Louisiana well-level attribution** (parallel to Texas RRC approach)
   - Spatial join: plumes → SONRIS wells
   - Use current_operator from SONRIS (not OGIM)
   - Apply same confidence scoring methodology

3. **Cross-reference with R5T data** (optional enhancement)
   - Link well operator → transporter (via field aggregation)
   - Provides supply chain context for attribution

**Scripts Needed:**
- `scripts/download_sonris_wells.py` - Automated download (once method identified)
- `scripts/parse_sonris_wells.py` - Parse downloaded data to CSV
- `queries/load_sonris_wells.sql` - Load into DuckDB
- Update `queries/create_attribution.sql` - Add Louisiana well-level attribution logic

### Phase 3: Validation

1. **Compare SONRIS operators vs OGIM operators**
   - Measure operator name match rate
   - Identify wells with updated operators
   - Document operator name normalization needs

2. **Attribution impact analysis**
   - Re-run attribution with SONRIS operator data
   - Compare plume attribution before/after
   - Quantify improvements in Louisiana attribution

3. **Data freshness**
   - Document SONRIS update schedule
   - Establish refresh cadence for pipeline
   - Monitor for operator changes over time

## Implementation Effort Estimates

### Low Effort (If bulk download available)
- **Data acquisition**: 1-2 hours (create account, download, document)
- **Parser development**: 2-4 hours (similar to P4/P5 parsers)
- **Schema integration**: 2-3 hours (SQL updates)
- **Testing & validation**: 3-4 hours
- **Total**: ~8-13 hours

### Medium Effort (If IDR export required)
- **IDR automation**: 4-6 hours (Selenium scripting, CAPTCHA handling)
- **Parser development**: 3-5 hours (HTML/Excel parsing)
- **Schema integration**: 2-3 hours
- **Testing & validation**: 4-5 hours
- **Total**: ~13-19 hours

### High Effort (If manual contact required)
- **DNR coordination**: Variable (days-weeks for response)
- **Custom data pipeline**: 6-10 hours (depending on format)
- **Schema integration**: 2-3 hours
- **Testing & validation**: 4-5 hours
- **Total**: ~12-18 hours + coordination time

## Open Questions

1. **Data Access**
   - What authentication is required for SONRIS GIS download?
   - Can we automate IDR exports, or is manual download required?
   - Does Louisiana DNR provide bulk data APIs?

2. **Data Quality**
   - How current is the "Current Operator" field?
   - What is the operator update lag compared to P-4 data?
   - How complete is the API number mapping?

3. **Operator Naming**
   - Do SONRIS operator names match OGIM naming conventions?
   - Is there a SONRIS equivalent to P-5 (operator name standardization)?
   - What normalization is needed for LNG contract matching?

4. **Legal/Licensing**
   - Are there restrictions on bulk downloading SONRIS data?
   - Can we redistribute SONRIS-derived data?
   - What attribution is required?

## Current R5T Integration: Keep or Remove?

### Recommendation: **Keep R5T, Add Well Data**

**Keep R5T because:**
- Provides field-level transporter relationship context
- Useful for understanding gas supply chains to LNG facilities
- Minimal maintenance burden (optional, already working)
- No performance impact (small dataset: ~5,500 records)

**Add well data because:**
- Provides well-level operator attribution (core mission)
- Enables Louisiana-Texas parity in attribution quality
- Significantly improves Louisiana plume attribution accuracy
- Addresses the fundamental data gap

**Combined value:**
- Well data: Spatial attribution (plume → operator)
- R5T data: Supply chain context (operator → transporter → LNG)
- Together: Complete chain from plume source to end-use facility

## Next Steps

1. ✅ **Document findings** (this document)
2. ⏸️ **Investigate SONRIS well data access** (when ready to proceed)
3. ⏸️ **Prototype well data integration** (after data access secured)
4. ⏸️ **Evaluate attribution improvements** (validate approach)
5. ⏸️ **Production implementation** (full pipeline integration)

## References

- **SONRIS Main Portal**: https://sonris.com/
- **SONRIS GIS Downloads**: http://sonris-gis.dnr.state.la.us/website/DownloadLogin.html (requires auth)
- **SONRIS Data Portal**: https://www.dnr.louisiana.gov/page/cons-sonris-idr-index-by-topic
- **Louisiana DNR Contact**: Beverly Kahl, (225) 342-4618, Beverly.kahl@la.gov
- **Current R5T Integration**: Commit d8f5312 "Add Louisiana SONRIS Form R5T data integration"

---

*Document created: 2025-10-03*
*Status: Research phase - implementation pending data access investigation*
