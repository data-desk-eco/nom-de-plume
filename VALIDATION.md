# P4 Database Validation Report

## Database Summary

- **Total leases**: 543,919 (251,177 oil leases, 292,742 gas wells)
- **Active leases** (on schedule): 236,687 (43.5%)
- **Gatherer/Purchaser records**: 11,901,323
- **Lease names**: 543,919 (100% coverage after deduplication)
- **Unique operators**: 29,413
- **Unique gatherers/purchasers**: 7,369

## Data Quality

### Completeness
- ✅ All leases have operator information
- ✅ 100% of leases have names (after deduplication, 51k had NULL/empty initially)
- ✅ 90.6% of leases have gatherer/purchaser data
- ✅ No invalid percentages (all between 0 and 1)

### Split Ownership
- **123,476 leases** have split gatherer/purchaser arrangements
- Split scenarios breakdown:
  - Gatherers: 1,186,111 split connections (17% of all gatherer connections)
  - Purchasers: 483,313 split connections (15% of all purchaser connections)
  - Nominators: 171,993 split connections (9% of all nominator connections)

## Top Entities

### Largest Operators (by active lease count)
1. **386310**: 10,551 leases (807 oil, 9,744 gas)
2. **875310**: 8,381 leases (35 oil, 8,346 gas)
3. **760218**: 6,564 leases (740 oil, 5,824 gas)
4. **665748**: 4,854 leases (4,811 oil, 43 gas)
5. **220903**: 4,459 leases (104 oil, 4,355 gas)

### Largest Gatherers (by connection count)
1. **667883**: 312,599 connections across 92,515 unique leases
2. **829626**: 192,034 connections across 63,633 unique leases
3. **774715**: 182,111 connections across 58,430 unique leases
4. **239232**: 148,357 connections across 40,448 unique leases
5. **338201**: 143,320 connections across 55,322 unique leases

### Largest Purchasers (by connection count)
1. **252017**: 89,147 connections across 33,634 unique leases
2. **216732**: 87,468 connections across 19,169 unique leases
3. **195918**: 85,260 connections across 32,735 unique leases
4. **195959**: 72,462 connections across 29,953 unique leases
5. **230719**: 64,172 connections across 24,860 unique leases

## Example Use Cases for Methane Attribution

### 1. Find All Gatherers for an Operator
```sql
SELECT
    gp.gpn_number as gatherer_p5,
    COUNT(DISTINCT (l.oil_gas_code, l.district, l.lease_rrcid)) as num_leases
FROM leases l
JOIN gatherers_purchasers gp USING (oil_gas_code, district, lease_rrcid)
WHERE l.operator_number = 386310
    AND gp.type_code = 'G'
    AND l.on_off_schedule = 'N'
GROUP BY gp.gpn_number
ORDER BY num_leases DESC;
```

### 2. Find All Operators for a Gatherer
```sql
SELECT
    l.operator_number,
    COUNT(DISTINCT (l.oil_gas_code, l.district, l.lease_rrcid)) as num_leases,
    SUM(gp.actual_percent) as total_gathering_volume_proxy
FROM leases l
JOIN gatherers_purchasers gp USING (oil_gas_code, district, lease_rrcid)
WHERE gp.gpn_number = 667883
    AND gp.type_code = 'G'
    AND l.on_off_schedule = 'N'
GROUP BY l.operator_number
ORDER BY num_leases DESC;
```

### 3. Find Split Ownership Scenarios
```sql
SELECT
    l.oil_gas_code,
    l.district,
    l.lease_rrcid,
    ln.lease_name,
    l.operator_number,
    gp.gpn_number as company_p5,
    gp.type_code,
    gp.product_code,
    gp.actual_percent
FROM leases l
JOIN lease_names ln USING (oil_gas_code, district, lease_rrcid)
JOIN gatherers_purchasers gp USING (oil_gas_code, district, lease_rrcid)
WHERE gp.actual_percent < 1.0 AND gp.actual_percent > 0
    AND l.on_off_schedule = 'N'
ORDER BY l.lease_rrcid
LIMIT 100;
```

## Known Limitations

1. **No company names**: P-5 organization numbers are present but not company names. The P-5 organization file would need to be obtained separately from Texas RRC.

2. **No well locations**: Latitude/longitude coordinates are not in the P-4 file. Would need to join with well completion data (requires well API numbers) or use district/field information for rough geographic attribution.

3. **No production volumes**: The database shows relationships and percentages but not actual volumes. Production data would come from monthly production reports (P-2/P-3).

4. **Historical records**: Some leases have multiple records representing changes over time. We deduplicate to keep the most recent, but historical analysis would require preserving all records.

5. **Empty lease names**: About 9.4% of leases have NULL or empty names in the original data.

## Recommendations for Methane Attribution

For attributing methane plumes to operators:

1. **Cross-reference with well locations**: Obtain Texas RRC well completion data with lat/lon coordinates
2. **Add P-5 organization names**: Download P-5 organization file to map P-5 numbers to actual company names
3. **Incorporate production volumes**: Use P-2/P-3 production reports to weight responsibility by actual production
4. **Link to infrastructure data**: Match gatherer/purchaser networks to pipeline and compressor station locations
5. **Consider temporal aspects**: Some operations may have changed hands - preserve P-4 historical records with effective dates

## Database Schema

### Tables

**leases**
- oil_gas_code (VARCHAR): 'O' = oil lease, 'G' = gas well
- district (INTEGER): RRC district (1-14, with special codes for 6E, 7B, 7C, 8A, 8B)
- lease_rrcid (INTEGER): RRC-assigned lease/well ID
- field_number (INTEGER): RRC field number
- on_off_schedule (VARCHAR): 'N' = on schedule (active), 'Y' = off schedule
- operator_number (INTEGER): P-5 organization number of operator

**lease_names**
- oil_gas_code, district, lease_rrcid (foreign key to leases)
- lease_name (VARCHAR): Name of the lease/well

**gatherers_purchasers**
- oil_gas_code, district, lease_rrcid (foreign key to leases)
- product_code (VARCHAR): 'O'=oil, 'G'=gas well gas, 'H'=condensate, 'P'=casinghead gas, 'F'=full well stream
- type_code (VARCHAR): 'G'=gatherer, 'H'=purchaser, 'I'=nominator
- gpn_number (INTEGER): P-5 organization number of company
- purch_system_no (INTEGER): Purchaser system suffix number
- actual_percent (DOUBLE): Percentage of production (0.0 to 1.0)

## Data Sources

- **Source file**: data/p4f606.ebc.gz (203 MB compressed EBCDIC)
- **Documentation**: docs/p4-user-manual_p4a002_feb2015.txt
- **Format**: IBM mainframe EBCDIC (code page 500)
- **Records processed**: ~29.6 million raw records
- **Parsing approach**: Proper EBCDIC decoding using Python's cp500 encoding, not character lookup tables