#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys

from ship_callsign import ship_callsign_list


def ships():
    return ship_callsign_list()


def get_platform_code(file, mode):
    """
    # get code from netcdf file name
    """
    return get_file_parts(file, mode)[4]


def get_file_parts(file, mode):
    """
    # extract components of netcdf file name
    """
    file_parts = os.path.basename(file).split("_")
    # check validity of filename
    assert len(file_parts) >= 4, 'Filename should have at least 5 components'
    return file_parts


def get_facility(file, mode):
    """
    # get facility from file name
    """
    if mode == 'DM':
        return get_file_parts(file, mode)[1]  # <Facility-Code>
    else:
        facility = get_file_parts(file, mode)[1:3]
        if facility[0] == 'SOOP' and facility[1] == 'TMV1':
            return 'SOOP-TMV'


def get_year(file, mode):
    """
    # get year from netcdf file name
    """
    if mode == 'DM':
        return get_file_parts(file, mode)[3][:4]  # year out of <Start-date>
    else:
        return get_file_parts(file, mode)[4][:4]


def get_month(file, mode):
    """
    # get month from netcdf file name
    """
    if mode == 'DM':
        return get_file_parts(file, mode)[3][4:6]
    else:
        return get_file_parts(file, mode)[4][4:6]


def get_product_code(file, mode):
    """
    # extract the product code :'D2M', 'M2D', 'MEL', 'DEV'
    """
    if mode == 'DM':
        return get_file_parts(file, mode)[6][-3:]
    else:
        return get_file_parts(file, mode)[3][:]


def get_product_type(file, mode):
    """
    # infer product type (mooring or transect) from product code
    """
    product_code = get_product_code(file, mode)
    assert product_code in ['D2M', 'M2D', 'MEL',
                            'DEV'], "Invalid product_code '%s' " % product_code

    if product_code in ['D2M', 'M2D']:
        return "transect"
    else:
        return "mooring"


def get_platform(file, mode):
    code = get_platform_code(file, mode)  # check that code in platform vocab
    if code in ships():
        platform = ships()[code]
        return code + '_' + platform
    else:
        print >>sys.stderr, "Error parsing ship code from '%s' " % file
        exit(1)


def get_timestep(file):
    if os.path.basename(file).find("1SecRaw") > 0:
        return "1sec"
    else:
        return "10sec"


def set_destination_path(file, destination, mode):
    """
    # Determine path for archiving SOOP-TMV data:
    # Inputs:
    # - file: netcdf, log or zip file
    # - destination : 'S3' or 'archive'
    # - mode: either 'DM' or 'NRT'
    # Destination : 'archive'
    #     DM: set path for FV00 and FV01 (nonQC and QC NRT files) generated
    #         by the toolbox
    #     NRT: set path for NRT Zip files storing NRT data
    # Destination : 'S3'
    #     DM: set path for FV02  files
    #     NRT: set path for log files
    """
    facility = get_facility(file, mode)
    product_type = get_product_type(file, mode)
    year = get_year(file, mode)
    month = get_month(file, mode)

    if mode == 'DM':
        platform = get_platform(file, mode)
        if destination == 'archive':
            print os.path.join('SOOP', facility, platform, 'DM',
                               product_type, year, month)
        else:  # destination S3
            print os.path.join('SOOP', facility, platform, product_type,
                               year, month)

    elif mode == 'NRT':
        # same path to S3 and archive. condition on destination unnecessary
        platform = 'VLST_Spirit-of-Tasmania-1'
        timestep = get_timestep(file)
        print os.path.join(
             'SOOP', facility, platform, 'realtime', product_type,
             timestep, year, month)


if __name__ == '__main__':
    # read filename from command line

    if len(sys.argv) < 5:
        print >>sys.stderr, 'Not enough input arguments'
        exit(1)

    function = sys.argv[1]
    file = sys.argv[2]
    destination = sys.argv[3]
    mode = sys.argv[4]

    assert mode in ['DM', 'NRT'], "Invalid data mode"
    assert destination in ['S3', 'archive'], "Invalid destination"

    globals()[function](file, destination, mode)
