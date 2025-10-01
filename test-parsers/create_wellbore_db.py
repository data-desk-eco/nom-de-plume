#!/usr/bin/env python3
"""Parse Texas RRC Well Bore EBCDIC data and output to CSV files."""

import gzip
import sys
import csv
from parse_wellbore import parse_root_record, parse_new_location_record, parse_well_id_record


def main():
    input_file = sys.argv[1] if len(sys.argv) > 1 else "data/dbf900.ebc.gz"
    root_csv = sys.argv[2] if len(sys.argv) > 2 else "data/wellbore_root.csv"
    location_csv = sys.argv[3] if len(sys.argv) > 3 else "data/wellbore_location.csv"
    wellid_csv = sys.argv[4] if len(sys.argv) > 4 else "data/wellbore_wellid.csv"

    print(f"Parsing {input_file}...")

    with gzip.open(input_file, 'rb') as f, \
         open(root_csv, 'w', newline='') as root_out, \
         open(location_csv, 'w', newline='') as location_out, \
         open(wellid_csv, 'w', newline='') as wellid_out:

        root_writer = csv.writer(root_out)
        location_writer = csv.writer(location_out)
        wellid_writer = csv.writer(wellid_out)

        # Write headers
        root_writer.writerow([
            'api_county', 'api_unique', 'field_district', 'res_county_code',
            'orig_compl_century', 'orig_compl_year', 'orig_compl_month', 'orig_compl_day',
            'total_depth', 'newest_drill_permit_nbr',
            'fresh_water_flag', 'plug_flag', 'completion_data_ind'
        ])

        location_writer.writerow([
            'api_county', 'api_unique', 'loc_county', 'abstract', 'survey',
            'block_number', 'section', 'alt_section', 'alt_abstract',
            'feet_from_sur_sect_1', 'direc_from_sur_sect_1',
            'feet_from_sur_sect_2', 'direc_from_sur_sect_2',
            'wgs84_latitude', 'wgs84_longitude',
            'plane_zone', 'plane_coordinate_east', 'plane_coordinate_north',
            'verification_flag'
        ])

        wellid_writer.writerow([
            'api_county', 'api_unique', 'oil_gas_code', 'district',
            'lease_number', 'well_number', 'gas_rrcid'
        ])

        current_api = None
        record_count = 0
        root_count = 0
        location_count = 0
        wellid_count = 0

        while True:
            record = f.read(247)
            if not record or len(record) < 247:
                break

            record_count += 1
            if record_count % 100000 == 0:
                print(f"  Processed {record_count:,} records...")

            record_id = record[0:2].decode('cp500')

            if record_id == '01':
                # Root record - start of new well bore
                root = parse_root_record(record)
                current_api = (root.api_county, root.api_unique)

                root_writer.writerow([
                    root.api_county, root.api_unique, root.field_district, root.res_county_code,
                    root.orig_compl_century, root.orig_compl_year, root.orig_compl_month, root.orig_compl_day,
                    root.total_depth, root.newest_drill_permit_nbr,
                    root.fresh_water_flag, root.plug_flag, root.completion_data_ind
                ])
                root_count += 1

            elif record_id == '13' and current_api:
                # New location record
                loc = parse_new_location_record(record, current_api[0], current_api[1])

                location_writer.writerow([
                    loc.api_county, loc.api_unique, loc.loc_county, loc.abstract, loc.survey,
                    loc.block_number, loc.section, loc.alt_section, loc.alt_abstract,
                    loc.feet_from_sur_sect_1, loc.direc_from_sur_sect_1,
                    loc.feet_from_sur_sect_2, loc.direc_from_sur_sect_2,
                    loc.wgs84_latitude, loc.wgs84_longitude,
                    loc.plane_zone, loc.plane_coordinate_east, loc.plane_coordinate_north,
                    loc.verification_flag
                ])
                location_count += 1

            elif record_id == '21' and current_api:
                # Well-ID record - links API to RRC lease identifiers
                wellid = parse_well_id_record(record, current_api[0], current_api[1])

                wellid_writer.writerow([
                    wellid.api_county, wellid.api_unique, wellid.oil_gas_code, wellid.district,
                    wellid.lease_number, wellid.well_number, wellid.gas_rrcid
                ])
                wellid_count += 1

    print(f"\nParsed {root_count:,} well bore records, {location_count:,} location records, and {wellid_count:,} well-ID records")
    print(f"Output: {root_csv}, {location_csv}, {wellid_csv}")


if __name__ == '__main__':
    main()
