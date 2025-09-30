#!/usr/bin/env python3
"""Parse Texas RRC Well Bore EBCDIC data structures."""

from dataclasses import dataclass
import struct


@dataclass
class RootRecord:
    """Record type 01: Well Bore root (WBROOT)"""
    api_county: int
    api_unique: int
    field_district: int
    res_county_code: int
    orig_compl_century: int
    orig_compl_year: int
    orig_compl_month: int
    orig_compl_day: int
    total_depth: int
    newest_drill_permit_nbr: int
    fresh_water_flag: str
    plug_flag: str
    completion_data_ind: str


@dataclass
class NewLocationRecord:
    """Record type 13: Well Bore new location (WBNEWLOC)"""
    api_county: int
    api_unique: int
    loc_county: int
    abstract: str
    survey: str
    block_number: str
    section: str
    alt_section: str
    alt_abstract: str
    feet_from_sur_sect_1: int
    direc_from_sur_sect_1: str
    feet_from_sur_sect_2: int
    direc_from_sur_sect_2: str
    wgs84_latitude: float
    wgs84_longitude: float
    plane_zone: int
    plane_coordinate_east: float
    plane_coordinate_north: float
    verification_flag: str


def parse_root_record(record: bytes) -> RootRecord:
    """Parse Well Bore root record (type 01, 247 bytes)."""
    # Decode the record
    decoded = record.decode('cp500')

    # Extract fields based on positions from documentation
    api_county = int(decoded[2:5])
    api_unique = int(decoded[5:10])
    field_district = int(decoded[14:16])
    res_county_code = int(decoded[16:19])

    # Original completion date
    orig_compl_cent = int(decoded[20:22])
    orig_compl_year = int(decoded[22:24])
    orig_compl_month = int(decoded[24:26])
    orig_compl_day = int(decoded[26:28])

    # Well details
    total_depth = int(decoded[28:33])
    newest_drill_permit_nbr = int(decoded[80:86])

    # Flags
    fresh_water_flag = decoded[89]
    plug_flag = decoded[90]
    completion_data_ind = decoded[99]

    return RootRecord(
        api_county=api_county,
        api_unique=api_unique,
        field_district=field_district,
        res_county_code=res_county_code,
        orig_compl_century=orig_compl_cent,
        orig_compl_year=orig_compl_year,
        orig_compl_month=orig_compl_month,
        orig_compl_day=orig_compl_day,
        total_depth=total_depth,
        newest_drill_permit_nbr=newest_drill_permit_nbr,
        fresh_water_flag=fresh_water_flag,
        plug_flag=plug_flag,
        completion_data_ind=completion_data_ind
    )


def parse_new_location_record(record: bytes, api_county: int, api_unique: int) -> NewLocationRecord:
    """Parse Well Bore new location record (type 13, 247 bytes)."""
    # Decode the record
    decoded = record.decode('cp500')

    # Extract location fields
    loc_county = int(decoded[2:5])
    abstract = decoded[5:11].strip()
    survey = decoded[11:66].strip()
    block_number = decoded[66:76].strip()
    section = decoded[76:84].strip()
    alt_section = decoded[84:88].strip()
    alt_abstract = decoded[88:94].strip()

    # Distance from survey lines (can contain decimals despite PIC 9(06) in docs)
    feet_str_1 = decoded[94:100].strip()
    try:
        feet_from_sur_sect_1 = int(float(feet_str_1)) if feet_str_1 else 0
    except ValueError:
        feet_from_sur_sect_1 = 0
    direc_from_sur_sect_1 = decoded[100:113].strip()
    feet_str_2 = decoded[113:119].strip()
    try:
        feet_from_sur_sect_2 = int(float(feet_str_2)) if feet_str_2 else 0
    except ValueError:
        feet_from_sur_sect_2 = 0
    direc_from_sur_sect_2 = decoded[119:132].strip()

    # WGS84 coordinates - PIC S9(3)V9(7) EBCDIC zoned decimal (10 digits, 7 decimal places)
    # Position 133-142 (10 bytes for latitude)
    # Position 143-152 (10 bytes for longitude)
    wgs84_latitude = parse_ebcdic_signed_decimal(record[132:142], 7)
    wgs84_longitude = parse_ebcdic_signed_decimal(record[142:152], 7)

    # Plane coordinates
    plane_zone_str = decoded[157:159].strip()
    plane_zone = int(plane_zone_str) if plane_zone_str else 0

    # Plane coordinates - PIC S9(8)V9(2) EBCDIC zoned decimal (10 digits, 2 decimal places)
    plane_coordinate_east = parse_ebcdic_signed_decimal(record[159:169], 2)
    plane_coordinate_north = parse_ebcdic_signed_decimal(record[169:179], 2)

    verification_flag = decoded[177]

    return NewLocationRecord(
        api_county=api_county,
        api_unique=api_unique,
        loc_county=loc_county,
        abstract=abstract,
        survey=survey,
        block_number=block_number,
        section=section,
        alt_section=alt_section,
        alt_abstract=alt_abstract,
        feet_from_sur_sect_1=feet_from_sur_sect_1,
        direc_from_sur_sect_1=direc_from_sur_sect_1,
        feet_from_sur_sect_2=feet_from_sur_sect_2,
        direc_from_sur_sect_2=direc_from_sur_sect_2,
        wgs84_latitude=wgs84_latitude,
        wgs84_longitude=wgs84_longitude,
        plane_zone=plane_zone,
        plane_coordinate_east=plane_coordinate_east,
        plane_coordinate_north=plane_coordinate_north,
        verification_flag=verification_flag
    )


def parse_ebcdic_signed_decimal(data: bytes, decimal_places: int) -> float:
    """Parse EBCDIC zoned decimal with sign in last byte.

    In EBCDIC, signed numeric fields store the sign in the zone bits of the last byte:
    - 0xCn or 0xFn = positive digit (n = digit 0-9)
    - 0xDn = negative digit (n = digit 0-9)
    """
    if not data or len(data) == 0:
        return 0.0

    # Decode to EBCDIC string
    decoded = data.decode('cp500')

    # Last character contains the sign
    last_char = decoded[-1]
    last_byte = data[-1]

    # Extract the digit from last byte
    digit = last_byte & 0x0F

    # Check sign from zone bits
    zone = last_byte & 0xF0
    is_negative = (zone == 0xD0)

    # Build the number string
    digits = decoded[:-1] + str(digit)

    try:
        value = int(digits)
    except ValueError:
        return 0.0

    # Apply decimal scaling
    scaled_value = value / (10 ** decimal_places)

    return -scaled_value if is_negative else scaled_value


def unpack_comp3_decimal(data: bytes, integer_digits: int, decimal_digits: int) -> float:
    """Unpack COMP-3 (packed decimal) data.

    COMP-3 format stores two digits per byte, with the sign in the last nibble.
    For example, PIC S9(3)V9(7) stores 10 digits + sign in 5 bytes.
    """
    if not data or len(data) == 0:
        return 0.0

    # Convert bytes to string of hex digits
    hex_str = data.hex()

    # Last nibble is the sign (C=positive, D=negative, F=unsigned)
    sign_nibble = hex_str[-1].upper()
    is_negative = sign_nibble == 'D'

    # Extract digits (all nibbles except the last)
    digit_str = hex_str[:-1]

    # Convert to integer
    try:
        value = int(digit_str)
    except ValueError:
        return 0.0

    # Apply decimal scaling
    scaled_value = value / (10 ** decimal_digits)

    return -scaled_value if is_negative else scaled_value
