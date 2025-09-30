#!/usr/bin/env python3
"""Parse Texas RRC P4 EBCDIC data and output relevant fields."""

import gzip
import struct
import sys
from dataclasses import dataclass


@dataclass
class LeaseRecord:
    """Record type 01: Lease/P-4 root information"""
    oil_gas_code: str  # pos 3: O=oil, G=gas
    district: int  # pos 4-5
    lease_rrcid: int  # pos 6-11
    field_number: int  # pos 12-19
    on_off_schedule: str  # pos 20
    operator_number: int  # pos 21-26


@dataclass
class GathererPurchaserRecord:
    """Record type 03: Gatherer/Purchaser/Nominator"""
    product_code: str  # pos 3: F/G/H/O/P
    type_code: str  # pos 4: G=gatherer, H=purchaser, I=nominator
    percentage_key: float  # pos 5-9: PIC 9(01)V9(04)
    gpn_number: int  # pos 10-15: P-5 org number
    purch_system_no: int  # pos 16-19
    actual_percent: float  # pos 21-25: PIC 9(01)V9(04)


@dataclass
class LeaseNameRecord:
    """Record type 07: Lease name"""
    sequence_date_key: int  # pos 3-10
    effect_date_key: int  # pos 11-18
    lease_name: str  # pos 19-50


def parse_lease_record(data: bytes) -> LeaseRecord:
    """Parse record type 01."""
    oil_gas_code = data[2:3].decode('cp500').strip()
    district = int(data[3:5].decode('cp500'))
    lease_rrcid = int(data[5:11].decode('cp500'))
    field_number = int(data[11:19].decode('cp500'))
    on_off_schedule = data[19:20].decode('cp500')
    operator_number = int(data[20:26].decode('cp500'))

    return LeaseRecord(
        oil_gas_code=oil_gas_code,
        district=district,
        lease_rrcid=lease_rrcid,
        field_number=field_number,
        on_off_schedule=on_off_schedule,
        operator_number=operator_number
    )


def parse_gpn_record(data: bytes) -> GathererPurchaserRecord:
    """Parse record type 03."""
    product_code = data[2:3].decode('cp500').strip()
    type_code = data[3:4].decode('cp500').strip()
    # PIC 9(01)V9(04) - 5 EBCDIC digits with implicit decimal after 1st
    percentage_key = int(data[4:9].decode('cp500')) / 10000.0
    gpn_number = int(data[9:15].decode('cp500'))
    purch_system_no = int(data[15:19].decode('cp500'))
    # PIC 9(01)V9(04) - 5 EBCDIC digits with implicit decimal after 1st
    actual_percent = int(data[20:25].decode('cp500')) / 10000.0

    return GathererPurchaserRecord(
        product_code=product_code,
        type_code=type_code,
        percentage_key=percentage_key,
        gpn_number=gpn_number,
        purch_system_no=purch_system_no,
        actual_percent=actual_percent
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