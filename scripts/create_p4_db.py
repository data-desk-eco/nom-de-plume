#!/usr/bin/env python3
"""Parse Texas RRC P4 EBCDIC data and output to CSV."""

import gzip
import sys
import csv
from parse_p4 import parse_lease_record, parse_gpn_record


def main():
    input_file = sys.argv[1] if len(sys.argv) > 1 else "data/p4f606.ebc.gz"
    leases_csv = sys.argv[2] if len(sys.argv) > 2 else "data/p4_root.csv"
    gpn_csv = sys.argv[3] if len(sys.argv) > 3 else "data/gpn.csv"

    print(f"Parsing {input_file}...")

    with gzip.open(input_file, 'rb') as f, \
         open(leases_csv, 'w', newline='') as leases_out, \
         open(gpn_csv, 'w', newline='') as gpn_out:

        leases_writer = csv.writer(leases_out)
        gpn_writer = csv.writer(gpn_out)

        # Write headers
        leases_writer.writerow(['oil_gas_code', 'district', 'lease_rrcid', 'field_number',
                                'on_off_schedule', 'operator_number'])
        gpn_writer.writerow(['oil_gas_code', 'district', 'lease_rrcid', 'product_code',
                            'type_code', 'gpn_number', 'purch_system_no', 'actual_percent'])

        current_lease_key = None
        record_count = 0
        lease_count = 0
        gpn_count = 0

        while True:
            record = f.read(92)
            if not record or len(record) < 92:
                break

            record_count += 1
            if record_count % 100000 == 0:
                print(f"  Processed {record_count:,} records...")

            record_id = record[0:2].decode('cp500')

            if record_id == '01':
                lease = parse_lease_record(record)
                if lease is None:
                    current_lease_key = None
                    continue
                current_lease_key = (lease.oil_gas_code, lease.district, lease.lease_rrcid)
                leases_writer.writerow([
                    lease.oil_gas_code,
                    lease.district,
                    lease.lease_rrcid,
                    lease.field_number,
                    lease.on_off_schedule,
                    lease.operator_number,
                ])
                lease_count += 1

            elif record_id == '03' and current_lease_key:
                gpn = parse_gpn_record(record)
                if gpn is None:
                    continue
                gpn_writer.writerow([
                    current_lease_key[0],
                    current_lease_key[1],
                    current_lease_key[2],
                    gpn.product_code,
                    gpn.type_code,
                    gpn.gpn_number,
                    gpn.purch_system_no,
                    gpn.actual_percent,
                ])
                gpn_count += 1

    print(f"\nParsed {lease_count:,} leases and {gpn_count:,} gatherer/purchaser records")
    print(f"Output: {leases_csv}, {gpn_csv}")


if __name__ == '__main__':
    main()