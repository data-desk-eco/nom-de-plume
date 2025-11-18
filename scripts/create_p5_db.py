#!/usr/bin/env python3
"""Parse Texas RRC P-5 EBCDIC data and output to CSV files matching the schema."""

import gzip
import zipfile
import io
import sys
import csv
from parse_p5 import (
    parse_org_record,
    parse_specialty_code_record,
    parse_officer_record,
    parse_activity_indicator_record
)


def main():
    input_file = sys.argv[1] if len(sys.argv) > 1 else "data/orf850.ebc.gz"
    org_csv = sys.argv[2] if len(sys.argv) > 2 else "/tmp/p5_org.csv"
    specialty_csv = sys.argv[3] if len(sys.argv) > 3 else "/tmp/p5_specialty.csv"
    officer_csv = sys.argv[4] if len(sys.argv) > 4 else "/tmp/p5_officer.csv"
    activity_csv = sys.argv[5] if len(sys.argv) > 5 else "/tmp/p5_activity.csv"

    print(f"Parsing {input_file}...")

    # Detect file type by magic bytes
    with open(input_file, 'rb') as check:
        magic = check.read(2)

    if magic == b'PK':
        # ZIP file - extract contents
        with zipfile.ZipFile(input_file, 'r') as zf:
            name = zf.namelist()[0]
            zip_data = zf.read(name)
        # Check if inner file is also gzipped
        if zip_data[:2] == b'\x1f\x8b':
            gzip_file = gzip.GzipFile(fileobj=io.BytesIO(zip_data))
            f = io.BytesIO(gzip_file.read())
        else:
            f = io.BytesIO(zip_data)
    else:
        # Assume gzip
        f = gzip.open(input_file, 'rb')

    with open(org_csv, 'w', newline='') as org_out, \
         open(specialty_csv, 'w', newline='') as specialty_out, \
         open(officer_csv, 'w', newline='') as officer_out, \
         open(activity_csv, 'w', newline='') as activity_out:

        org_writer = csv.writer(org_out)
        specialty_writer = csv.writer(specialty_out)
        officer_writer = csv.writer(officer_out)
        activity_writer = csv.writer(activity_out)

        # Write headers
        org_writer.writerow([
            'operator_number', 'organization_name', 'refiling_required_flag',
            'p5_status', 'hold_mail_code', 'renewal_letter_code', 'organization_code',
            'organ_other_comment', 'gatherer_code',
            'org_addr_line1', 'org_addr_line2', 'org_addr_city', 'org_addr_state',
            'org_addr_zip', 'org_addr_zip_suffix',
            'location_addr_line1', 'location_addr_line2', 'location_addr_city',
            'location_addr_state', 'location_addr_zip', 'location_addr_zip_suffix',
            'date_built', 'date_inactive', 'phone_number'
        ])

        specialty_writer.writerow([
            'operator_number', 'organization_name', 'specialty_code',
            'spec_addr_line1', 'spec_addr_line2', 'spec_addr_city',
            'spec_addr_state', 'spec_addr_zip', 'spec_addr_zip_suffix'
        ])

        officer_writer.writerow([
            'operator_number', 'organization_name', 'officer_name', 'officer_title',
            'officer_addr_line1', 'officer_addr_line2', 'officer_addr_city',
            'officer_addr_state', 'officer_addr_zip', 'officer_addr_zip_suffix',
            'officer_type_id', 'officer_id_state', 'officer_id_number', 'officer_agent'
        ])

        activity_writer.writerow([
            'operator_number', 'organization_name', 'act_ind_code', 'act_ind_flag_districts'
        ])

        record_count = 0
        org_count = 0
        specialty_count = 0
        officer_count = 0
        activity_count = 0

        while True:
            # P-5 records are 350 bytes (per manual: record length 350)
            record = f.read(350)
            if not record or len(record) < 350:
                break

            record_count += 1
            if record_count % 100000 == 0:
                print(f"  Processed {record_count:,} records...")

            record_id = record[0:2].decode('cp500')

            if record_id == '1T':
                # Specialty/activity code table - skip for now
                # Could be loaded to a separate table if needed
                continue

            elif record_id == 'A ':
                org = parse_org_record(record)
                org_writer.writerow([
                    org.operator_number, org.organization_name, org.refiling_required_flag,
                    org.p5_status, org.hold_mail_code, org.renewal_letter_code,
                    org.organization_code, org.organ_other_comment, org.gatherer_code,
                    org.org_addr_line1, org.org_addr_line2, org.org_addr_city,
                    org.org_addr_state, org.org_addr_zip, org.org_addr_zip_suffix,
                    org.location_addr_line1, org.location_addr_line2, org.location_addr_city,
                    org.location_addr_state, org.location_addr_zip, org.location_addr_zip_suffix,
                    org.date_built, org.date_inactive, org.phone_number
                ])
                org_count += 1

            elif record_id == 'F ':
                spec = parse_specialty_code_record(record)
                specialty_writer.writerow([
                    spec.operator_number, spec.organization_name, spec.specialty_code,
                    spec.spec_addr_line1, spec.spec_addr_line2, spec.spec_addr_city,
                    spec.spec_addr_state, spec.spec_addr_zip, spec.spec_addr_zip_suffix
                ])
                specialty_count += 1

            elif record_id == 'K ':
                officer = parse_officer_record(record)
                officer_writer.writerow([
                    officer.operator_number, officer.organization_name,
                    officer.officer_name, officer.officer_title,
                    officer.officer_addr_line1, officer.officer_addr_line2, officer.officer_addr_city,
                    officer.officer_addr_state, officer.officer_addr_zip, officer.officer_addr_zip_suffix,
                    officer.officer_type_id, officer.officer_id_state,
                    officer.officer_id_number, officer.officer_agent
                ])
                officer_count += 1

            elif record_id == 'U ':
                act = parse_activity_indicator_record(record)
                activity_writer.writerow([
                    act.operator_number, act.organization_name,
                    act.act_ind_code, act.act_ind_flag_districts
                ])
                activity_count += 1

    print(f"\nParsed {org_count:,} organizations, {specialty_count:,} specialty codes, "
          f"{officer_count:,} officers, and {activity_count:,} activity indicators")
    print(f"Output: {org_csv}, {specialty_csv}, {officer_csv}, {activity_csv}")


if __name__ == '__main__':
    main()
