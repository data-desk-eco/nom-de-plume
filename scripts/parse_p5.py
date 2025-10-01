#!/usr/bin/env python3
"""Parse Texas RRC P5 (Organization Report) EBCDIC data."""

import gzip
import sys
from dataclasses import dataclass


@dataclass
class OrgRecord:
    """Record type 'A ': Organization information"""
    operator_number: int  # pos 3-8
    organization_name: str  # pos 9-40
    refiling_required_flag: str  # pos 41
    p5_status: str  # pos 42: A=active, I=inactive, D=delinquent, S=see remarks
    hold_mail_code: str  # pos 43
    renewal_letter_code: str  # pos 44
    organization_code: str  # pos 45: A=corp, B=lim.partnership, C=sole prop, D=partnership, E=trust, F=joint venture, G=other
    organ_other_comment: str  # pos 46-65
    gatherer_code: str  # pos 66-70
    org_addr_line1: str  # pos 71-101
    org_addr_line2: str  # pos 102-132
    org_addr_city: str  # pos 133-145
    org_addr_state: str  # pos 146-147
    org_addr_zip: str  # pos 148-152 (5 digits)
    org_addr_zip_suffix: str  # pos 153-156 (4 digits)
    location_addr_line1: str  # pos 157-187
    location_addr_line2: str  # pos 188-218
    location_addr_city: str  # pos 219-231
    location_addr_state: str  # pos 232-233
    location_addr_zip: str  # pos 234-238
    location_addr_zip_suffix: str  # pos 239-242
    date_built: str  # pos 243-250 (CCYYMMDD)
    date_inactive: str  # pos 251-258 (CCYYMMDD)
    phone_number: str  # pos 259-268 (10 digits)


@dataclass
class SpecialtyCodeRecord:
    """Record type 'F ': Specialty codes"""
    operator_number: int  # pos 3-8
    organization_name: str  # pos 9-40
    specialty_code: str  # pos 41-46
    spec_addr_line1: str  # pos 47-77
    spec_addr_line2: str  # pos 78-108
    spec_addr_city: str  # pos 109-121
    spec_addr_state: str  # pos 122-123
    spec_addr_zip: str  # pos 124-128
    spec_addr_zip_suffix: str  # pos 129-132


@dataclass
class OfficerRecord:
    """Record type 'K ': Officer information"""
    operator_number: int  # pos 3-8
    organization_name: str  # pos 9-40
    officer_name: str  # pos 41-72
    officer_title: str  # pos 73-104
    officer_addr_line1: str  # pos 105-135
    officer_addr_line2: str  # pos 136-166
    officer_addr_city: str  # pos 167-179
    officer_addr_state: str  # pos 180-181
    officer_addr_zip: str  # pos 182-186
    officer_addr_zip_suffix: str  # pos 187-190
    officer_type_id: str  # pos 277: L=driver's license, I=state ID
    officer_id_state: str  # pos 278-279
    officer_id_number: str  # pos 280-299
    officer_agent: str  # pos 300: A=agent, O=officer


@dataclass
class ActivityIndicatorRecord:
    """Record type 'U ': Activity indicator"""
    operator_number: int  # pos 3-8
    organization_name: str  # pos 9-40
    act_ind_code: str  # pos 41-46
    act_ind_flag_districts: str  # pos 47-60 (14 digits, one per district)


def parse_org_record(data: bytes) -> OrgRecord:
    """Parse record type 'A '."""
    operator_number = int(data[2:8].decode('cp500'))
    organization_name = data[8:40].decode('cp500').strip()
    refiling_required_flag = data[40:41].decode('cp500')
    p5_status = data[41:42].decode('cp500')
    hold_mail_code = data[42:43].decode('cp500')
    renewal_letter_code = data[43:44].decode('cp500')
    organization_code = data[44:45].decode('cp500')
    organ_other_comment = data[45:65].decode('cp500').strip()
    gatherer_code = data[65:70].decode('cp500').strip()
    org_addr_line1 = data[70:101].decode('cp500').strip()
    org_addr_line2 = data[101:132].decode('cp500').strip()
    org_addr_city = data[132:145].decode('cp500').strip()
    org_addr_state = data[145:147].decode('cp500').strip()
    org_addr_zip = data[147:152].decode('cp500').strip()
    org_addr_zip_suffix = data[152:156].decode('cp500').strip()
    location_addr_line1 = data[156:187].decode('cp500').strip()
    location_addr_line2 = data[187:218].decode('cp500').strip()
    location_addr_city = data[218:231].decode('cp500').strip()
    location_addr_state = data[231:233].decode('cp500').strip()
    location_addr_zip = data[233:238].decode('cp500').strip()
    location_addr_zip_suffix = data[238:242].decode('cp500').strip()
    date_built = data[242:250].decode('cp500').strip()
    date_inactive = data[250:258].decode('cp500').strip()
    phone_number = data[258:268].decode('cp500').strip()

    return OrgRecord(
        operator_number=operator_number,
        organization_name=organization_name,
        refiling_required_flag=refiling_required_flag,
        p5_status=p5_status,
        hold_mail_code=hold_mail_code,
        renewal_letter_code=renewal_letter_code,
        organization_code=organization_code,
        organ_other_comment=organ_other_comment,
        gatherer_code=gatherer_code,
        org_addr_line1=org_addr_line1,
        org_addr_line2=org_addr_line2,
        org_addr_city=org_addr_city,
        org_addr_state=org_addr_state,
        org_addr_zip=org_addr_zip,
        org_addr_zip_suffix=org_addr_zip_suffix,
        location_addr_line1=location_addr_line1,
        location_addr_line2=location_addr_line2,
        location_addr_city=location_addr_city,
        location_addr_state=location_addr_state,
        location_addr_zip=location_addr_zip,
        location_addr_zip_suffix=location_addr_zip_suffix,
        date_built=date_built,
        date_inactive=date_inactive,
        phone_number=phone_number
    )


def parse_specialty_code_record(data: bytes) -> SpecialtyCodeRecord:
    """Parse record type 'F '."""
    operator_number = int(data[2:8].decode('cp500'))
    organization_name = data[8:40].decode('cp500').strip()
    specialty_code = data[40:46].decode('cp500').strip()
    spec_addr_line1 = data[46:77].decode('cp500').strip()
    spec_addr_line2 = data[77:108].decode('cp500').strip()
    spec_addr_city = data[108:121].decode('cp500').strip()
    spec_addr_state = data[121:123].decode('cp500').strip()
    spec_addr_zip = data[123:128].decode('cp500').strip()
    spec_addr_zip_suffix = data[128:132].decode('cp500').strip()

    return SpecialtyCodeRecord(
        operator_number=operator_number,
        organization_name=organization_name,
        specialty_code=specialty_code,
        spec_addr_line1=spec_addr_line1,
        spec_addr_line2=spec_addr_line2,
        spec_addr_city=spec_addr_city,
        spec_addr_state=spec_addr_state,
        spec_addr_zip=spec_addr_zip,
        spec_addr_zip_suffix=spec_addr_zip_suffix
    )


def parse_officer_record(data: bytes) -> OfficerRecord:
    """Parse record type 'K '."""
    operator_number = int(data[2:8].decode('cp500'))
    organization_name = data[8:40].decode('cp500').strip()
    officer_name = data[40:72].decode('cp500').strip()
    officer_title = data[72:104].decode('cp500').strip()
    officer_addr_line1 = data[104:135].decode('cp500').strip()
    officer_addr_line2 = data[135:166].decode('cp500').strip()
    officer_addr_city = data[166:179].decode('cp500').strip()
    officer_addr_state = data[179:181].decode('cp500').strip()
    officer_addr_zip = data[181:186].decode('cp500').strip()
    officer_addr_zip_suffix = data[186:190].decode('cp500').strip()
    officer_type_id = data[276:277].decode('cp500').strip()
    officer_id_state = data[277:279].decode('cp500').strip()
    officer_id_number = data[279:299].decode('cp500').strip()
    officer_agent = data[299:300].decode('cp500').strip()

    return OfficerRecord(
        operator_number=operator_number,
        organization_name=organization_name,
        officer_name=officer_name,
        officer_title=officer_title,
        officer_addr_line1=officer_addr_line1,
        officer_addr_line2=officer_addr_line2,
        officer_addr_city=officer_addr_city,
        officer_addr_state=officer_addr_state,
        officer_addr_zip=officer_addr_zip,
        officer_addr_zip_suffix=officer_addr_zip_suffix,
        officer_type_id=officer_type_id,
        officer_id_state=officer_id_state,
        officer_id_number=officer_id_number,
        officer_agent=officer_agent
    )


def parse_activity_indicator_record(data: bytes) -> ActivityIndicatorRecord:
    """Parse record type 'U '."""
    operator_number = int(data[2:8].decode('cp500'))
    organization_name = data[8:40].decode('cp500').strip()
    act_ind_code = data[40:46].decode('cp500').strip()
    act_ind_flag_districts = data[46:60].decode('cp500')

    return ActivityIndicatorRecord(
        operator_number=operator_number,
        organization_name=organization_name,
        act_ind_code=act_ind_code,
        act_ind_flag_districts=act_ind_flag_districts
    )


def main():
    input_file = sys.argv[1] if len(sys.argv) > 1 else "data/orf850.ebc.gz"

    with gzip.open(input_file, 'rb') as f:
        current_org = None
        record_count = 0

        while True:
            # P-5 records are 350 bytes (per manual)
            record = f.read(350)
            if not record or len(record) < 350:
                break

            record_count += 1
            record_id = record[0:2].decode('cp500')

            if record_id == '1T':
                # Specialty/activity code table - skip for now
                continue

            elif record_id == 'A ':
                current_org = parse_org_record(record)
                print(f"ORG: {current_org.operator_number:06d} "
                      f"{current_org.organization_name[:40]} "
                      f"Status={current_org.p5_status}")

            elif record_id == 'F ' and current_org:
                spec = parse_specialty_code_record(record)
                print(f"  SPECIALTY: {spec.specialty_code}")

            elif record_id == 'K ' and current_org:
                officer = parse_officer_record(record)
                print(f"  OFFICER: {officer.officer_name} - {officer.officer_title}")

            elif record_id == 'U ' and current_org:
                act = parse_activity_indicator_record(record)
                print(f"  ACTIVITY: {act.act_ind_code}")

        print(f"\nProcessed {record_count:,} records")


if __name__ == '__main__':
    main()
