#!/usr/bin/env python3
"""Parse Texas RRC P-4 EBCDIC data and output to CSV files matching the schema."""

import gzip
import sys
import csv
from parse_p4 import parse_root_record, parse_info_record, parse_gpn_record, parse_lease_name_record


def main():
    input_file = sys.argv[1] if len(sys.argv) > 1 else "data/p4f606.ebc.gz"
    root_csv = sys.argv[2] if len(sys.argv) > 2 else "/tmp/root.csv"
    info_csv = sys.argv[3] if len(sys.argv) > 3 else "/tmp/info.csv"
    gpn_csv = sys.argv[4] if len(sys.argv) > 4 else "/tmp/gpn.csv"
    lease_name_csv = sys.argv[5] if len(sys.argv) > 5 else "/tmp/lease_name.csv"

    print(f"Parsing {input_file}...")

    with gzip.open(input_file, 'rb') as f, \
         open(root_csv, 'w', newline='') as root_out, \
         open(info_csv, 'w', newline='') as info_out, \
         open(gpn_csv, 'w', newline='') as gpn_out, \
         open(lease_name_csv, 'w', newline='') as lease_name_out:

        root_writer = csv.writer(root_out)
        info_writer = csv.writer(info_out)
        gpn_writer = csv.writer(gpn_out)
        lease_name_writer = csv.writer(lease_name_out)

        # Write headers
        root_writer.writerow(['oil_gas_code', 'district', 'lease_rrcid', 'field_number',
                              'on_off_schedule_indicator', 'operator_number'])

        info_writer.writerow(['oil_gas_code', 'district', 'lease_rrcid', 'sequence_date_key',
                              'effective_date_key', 'effective_year', 'effective_month', 'effective_day',
                              'approval_year', 'approval_month', 'approval_day',
                              'new_well', 'change_of_gatherer', 'change_of_purchaser', 'change_of_nominator',
                              'chg_purch_system_no', 'change_of_field', 'change_of_operator', 'change_of_lease_name',
                              'consolidation_lease', 'subdivision_lease', 'reclassification', 'special_form_filed',
                              'oil_field_transfer', 'type_record', 'info_field_number', 'info_operator_number',
                              'p5_number_filing_on_tape'])

        gpn_writer.writerow(['oil_gas_code', 'district', 'lease_rrcid', 'sequence_date_key',
                            'product_code', 'type_code', 'percentage_key', 'gpn_number', 'purch_system_no',
                            'current_p4_filing', 'actual_percent', 'inter_flag', 'intra_flag'])

        lease_name_writer.writerow(['oil_gas_code', 'district', 'lease_rrcid', 'sequence_date_key',
                                    'effect_date_key', 'lease_name'])

        current_lease_key = None
        info_records = []  # Buffer info records for current lease
        gpn_records = []   # Buffer gpn records for current lease
        lease_name_records = []  # Buffer lease name records for current lease

        record_count = 0
        root_count = 0
        info_count = 0
        gpn_count = 0
        lease_name_count = 0

        def write_lease():
            """Write all buffered records for the current lease."""
            nonlocal info_count, gpn_count, lease_name_count

            for info in info_records:
                info_writer.writerow([
                    current_lease_key[0], current_lease_key[1], current_lease_key[2],
                    info.sequence_date_key, info.effective_date_key,
                    info.effective_year, info.effective_month, info.effective_day,
                    info.approval_year, info.approval_month, info.approval_day,
                    info.new_well, info.change_of_gatherer, info.change_of_purchaser, info.change_of_nominator,
                    info.chg_purch_system_no, info.change_of_field, info.change_of_operator, info.change_of_lease_name,
                    info.consolidation_lease, info.subdivision_lease, info.reclassification, info.special_form_filed,
                    info.oil_field_transfer, info.type_record, info.info_field_number, info.info_operator_number,
                    info.p5_number_filing_on_tape
                ])
                info_count += 1

            for gpn in gpn_records:
                gpn_writer.writerow([
                    current_lease_key[0], current_lease_key[1], current_lease_key[2],
                    gpn[0],  # sequence_date_key
                    gpn[1].product_code, gpn[1].type_code, gpn[1].percentage_key, gpn[1].gpn_number,
                    gpn[1].purch_system_no, gpn[1].current_p4_filing, gpn[1].actual_percent,
                    gpn[1].inter_flag, gpn[1].intra_flag
                ])
                gpn_count += 1

            for ln in lease_name_records:
                lease_name_writer.writerow([
                    current_lease_key[0], current_lease_key[1], current_lease_key[2],
                    ln.sequence_date_key, ln.effect_date_key, ln.lease_name
                ])
                lease_name_count += 1

        while True:
            record = f.read(92)
            if not record or len(record) < 92:
                break

            record_count += 1
            if record_count % 100000 == 0:
                print(f"  Processed {record_count:,} records...")

            record_id = record[0:2].decode('cp500')

            if record_id == '01':
                # Write previous lease if we have one
                if current_lease_key is not None:
                    write_lease()

                # Start new lease
                root = parse_root_record(record)
                current_lease_key = (root.oil_gas_code, root.district, root.lease_rrcid)

                root_writer.writerow([
                    root.oil_gas_code, root.district, root.lease_rrcid,
                    root.field_number, root.on_off_schedule_indicator, root.operator_number
                ])
                root_count += 1

                info_records = []
                gpn_records = []
                lease_name_records = []

            elif record_id == '02' and current_lease_key:
                info = parse_info_record(record)
                info_records.append(info)

            elif record_id == '03' and current_lease_key and info_records:
                gpn = parse_gpn_record(record)
                # Associate with most recent info record
                gpn_records.append((info_records[-1].sequence_date_key, gpn))

            elif record_id == '07' and current_lease_key:
                ln = parse_lease_name_record(record)
                if ln.lease_name:  # Only store non-empty names
                    lease_name_records.append(ln)

        # Write final lease
        if current_lease_key is not None:
            write_lease()

    print(f"\nParsed {root_count:,} root records, {info_count:,} info records, {gpn_count:,} GPN records, and {lease_name_count:,} lease name records")
    print(f"Output: {root_csv}, {info_csv}, {gpn_csv}, {lease_name_csv}")


if __name__ == '__main__':
    main()
