#!/usr/bin/env python3
"""Parse Texas RRC P4 EBCDIC data and output relevant fields."""

import gzip
import struct
import sys
from dataclasses import dataclass


@dataclass
class RootRecord:
    """Record type 01: Lease/P-4 root information (current schedule state)"""
    oil_gas_code: str  # pos 3
    district: int  # pos 4-5
    lease_rrcid: int  # pos 6-11
    field_number: int  # pos 12-19
    on_off_schedule_indicator: str  # pos 20
    operator_number: int  # pos 21-26


@dataclass
class InfoRecord:
    """Record type 02: P-4 information record (temporal filing)"""
    sequence_date_key: int  # pos 3-10
    effective_date_key: int  # pos 11-18
    effective_year: int  # pos 19-22
    effective_month: int  # pos 23-24
    effective_day: int  # pos 25-26
    approval_year: int  # pos 27-30
    approval_month: int  # pos 31-32
    approval_day: int  # pos 33-34
    new_well: str  # pos 35
    change_of_gatherer: str  # pos 36
    change_of_purchaser: str  # pos 37
    change_of_nominator: str  # pos 38
    chg_purch_system_no: str  # pos 39
    change_of_field: str  # pos 40
    change_of_operator: str  # pos 41
    change_of_lease_name: str  # pos 42
    consolidation_lease: str  # pos 43
    subdivision_lease: str  # pos 44
    reclassification: str  # pos 45
    special_form_filed: str  # pos 46
    oil_field_transfer: str  # pos 47
    type_record: str  # pos 51
    info_field_number: int  # pos 52-59
    info_operator_number: int  # pos 60-65
    p5_number_filing_on_tape: int  # pos 66-71


@dataclass
class GpnRecord:
    """Record type 03: Gatherer/Purchaser/Nominator"""
    product_code: str  # pos 3
    type_code: str  # pos 4
    percentage_key: float  # pos 5-9: PIC 9(01)V9(04)
    gpn_number: int  # pos 10-15
    purch_system_no: int  # pos 16-19
    current_p4_filing: str  # pos 20
    actual_percent: float  # pos 21-25: PIC 9(01)V9(04)
    inter_flag: str  # pos 26
    intra_flag: str  # pos 27


@dataclass
class LeaseNameRecord:
    """Record type 07: Lease name"""
    sequence_date_key: int  # pos 3-10
    effect_date_key: int  # pos 11-18
    lease_name: str  # pos 19-50


def parse_root_record(data: bytes) -> RootRecord:
    """Parse record type 01."""
    oil_gas_code = data[2:3].decode('cp500').strip()
    district = int(data[3:5].decode('cp500'))
    lease_rrcid = int(data[5:11].decode('cp500'))
    field_number = int(data[11:19].decode('cp500'))
    on_off_schedule_indicator = data[19:20].decode('cp500')
    operator_number = int(data[20:26].decode('cp500'))

    return RootRecord(
        oil_gas_code=oil_gas_code,
        district=district,
        lease_rrcid=lease_rrcid,
        field_number=field_number,
        on_off_schedule_indicator=on_off_schedule_indicator,
        operator_number=operator_number
    )


def parse_gpn_record(data: bytes) -> GpnRecord:
    """Parse record type 03."""
    product_code = data[2:3].decode('cp500').strip()
    type_code = data[3:4].decode('cp500').strip()
    # PIC 9(01)V9(04) - 5 EBCDIC digits with implicit decimal after 1st
    percentage_key = int(data[4:9].decode('cp500')) / 10000.0
    gpn_number = int(data[9:15].decode('cp500'))
    purch_system_no = int(data[15:19].decode('cp500'))
    current_p4_filing = data[19:20].decode('cp500')
    # PIC 9(01)V9(04) - 5 EBCDIC digits with implicit decimal after 1st
    actual_percent = int(data[20:25].decode('cp500')) / 10000.0
    inter_flag = data[25:26].decode('cp500')
    intra_flag = data[26:27].decode('cp500')

    return GpnRecord(
        product_code=product_code,
        type_code=type_code,
        percentage_key=percentage_key,
        gpn_number=gpn_number,
        purch_system_no=purch_system_no,
        current_p4_filing=current_p4_filing,
        actual_percent=actual_percent,
        inter_flag=inter_flag,
        intra_flag=intra_flag
    )


def parse_info_record(data: bytes) -> InfoRecord:
    """Parse record type 02."""
    sequence_date_key = int(data[2:10].decode('cp500'))
    effective_date_key = int(data[10:18].decode('cp500'))
    effective_year = int(data[18:22].decode('cp500'))
    effective_month = int(data[22:24].decode('cp500'))
    effective_day = int(data[24:26].decode('cp500'))
    approval_year = int(data[26:30].decode('cp500'))
    approval_month = int(data[30:32].decode('cp500'))
    approval_day = int(data[32:34].decode('cp500'))
    new_well = data[34:35].decode('cp500')
    change_of_gatherer = data[35:36].decode('cp500')
    change_of_purchaser = data[36:37].decode('cp500')
    change_of_nominator = data[37:38].decode('cp500')
    chg_purch_system_no = data[38:39].decode('cp500')
    change_of_field = data[39:40].decode('cp500')
    change_of_operator = data[40:41].decode('cp500')
    change_of_lease_name = data[41:42].decode('cp500')
    consolidation_lease = data[42:43].decode('cp500')
    subdivision_lease = data[43:44].decode('cp500')
    reclassification = data[44:45].decode('cp500')
    special_form_filed = data[45:46].decode('cp500')
    oil_field_transfer = data[46:47].decode('cp500')
    type_record = data[50:51].decode('cp500')
    info_field_number = int(data[51:59].decode('cp500'))
    info_operator_number = int(data[59:65].decode('cp500'))
    p5_number_filing_on_tape = int(data[65:71].decode('cp500'))

    return InfoRecord(
        sequence_date_key=sequence_date_key,
        effective_date_key=effective_date_key,
        effective_year=effective_year,
        effective_month=effective_month,
        effective_day=effective_day,
        approval_year=approval_year,
        approval_month=approval_month,
        approval_day=approval_day,
        new_well=new_well,
        change_of_gatherer=change_of_gatherer,
        change_of_purchaser=change_of_purchaser,
        change_of_nominator=change_of_nominator,
        chg_purch_system_no=chg_purch_system_no,
        change_of_field=change_of_field,
        change_of_operator=change_of_operator,
        change_of_lease_name=change_of_lease_name,
        consolidation_lease=consolidation_lease,
        subdivision_lease=subdivision_lease,
        reclassification=reclassification,
        special_form_filed=special_form_filed,
        oil_field_transfer=oil_field_transfer,
        type_record=type_record,
        info_field_number=info_field_number,
        info_operator_number=info_operator_number,
        p5_number_filing_on_tape=p5_number_filing_on_tape
    )


def parse_lease_name_record(data: bytes) -> LeaseNameRecord:
    """Parse record type 07."""
    sequence_date_key = int(data[2:10].decode('cp500'))
    effect_date_key = int(data[10:18].decode('cp500'))
    lease_name = data[18:50].decode('cp500').strip()
    return LeaseNameRecord(
        sequence_date_key=sequence_date_key,
        effect_date_key=effect_date_key,
        lease_name=lease_name
    )


def main():
    input_file = sys.argv[1] if len(sys.argv) > 1 else "data/p4f606.ebc.gz"

    with gzip.open(input_file, 'rb') as f:
        current_lease = None

        while True:
            record = f.read(92)
            if not record or len(record) < 92:
                break

            record_id = record[0:2].decode('cp500')

            if record_id == '01':
                current_lease = parse_lease_record(record)
                print(f"LEASE: {current_lease.oil_gas_code} "
                      f"District={current_lease.district} "
                      f"ID={current_lease.lease_rrcid} "
                      f"Operator={current_lease.operator_number}")

            elif record_id == '03' and current_lease:
                gpn = parse_gpn_record(record)
                type_name = {'G': 'Gatherer', 'H': 'Purchaser', 'I': 'Nominator'}.get(gpn.type_code, gpn.type_code)
                print(f"  {type_name}: P5#{gpn.gpn_number} "
                      f"Product={gpn.product_code} "
                      f"Percent={gpn.actual_percent:.4f}")


if __name__ == '__main__':
    main()