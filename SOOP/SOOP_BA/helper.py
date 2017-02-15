#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys

from netCDF4 import Dataset

from ship_callsign import ship_callsign_list as ships


def get_file_parts(nc_file):
    return os.path.basename(nc_file).split("_")


def get_facility(nc_file):
    return get_file_parts(nc_file)[1]


def get_code(nc_file):
    return get_file_parts(nc_file)[4]


def get_code_long(nc_file):
    code = get_code(nc_file)

    if code in ships():
        return ships()[code]
    else:
        print >>sys.stderr, "Error parsing ship code from '%s' " % nc_file
        exit(1)


def get_platform(nc_file):
    return get_code(nc_file) + "_" + get_code_long(nc_file)


def open_dataset(nc_file, mode):
    try:
        return Dataset(nc_file, mode=mode)
    except:
        print >>sys.stderr, "Failed to open NetCDF file '%s', mode '%s'" % nc_file, mode
        exit(1)


def get_reporting_id(nc_file):
    F = open_dataset(nc_file, 'r')
    code = get_code_long(nc_file)
    date_start = getattr(F, 'time_coverage_start', '')
    date_end = getattr(F, 'time_coverage_end', '')
    F.close()

    if (not date_start or not date_end):
        print >>sys.stderr, "Missing date_start/date_end in '%s' " % nc_file
        return None

    try:
        return code + '_' + date_start[:10].replace('-', '') + '-' + date_end[:10].replace('-', '')
    except:
        print >>sys.stderr, "Failed getting reporting_id from NetCDF file '%s'" % nc_file
        exit(1)


def add_reporting_id(nc_file):
    # to ensure consitency in the format of the data ID
    # (voyage_id and deployemnt_id not always consistent),
    # add a reporting_id to the file : this is the variable i
    # to use for reporting from now on.
    # reporting_id based on ship name, start and end date

    F = open_dataset(nc_file, 'r+')
    reporting_id = get_reporting_id(nc_file)
    F.reporting_id = str(reporting_id)
    F.close()

    exit(0)


def dest_path(nc_file):
    """
    # eg :   IMOS_SOOP-BA_AE_20110309T220303Z_WTEE_FV02_Oscar-Elton-Sette-38-120_END-20110324T172032Z_C-20141002T013852Z.nc
    # IMOS_<Facility-Code>_<Data-Code>_<Start-date>_<Platform-Code>_FV<File-Version>_vessel_name_*.nc
    """

    if len(get_file_parts(nc_file)) < 6:
        print >>sys.stderr, "File '%s' does not have enough parts" % nc_file
        return None

    print os.path.join(
        "SOOP",
        get_facility(nc_file),  # <Facility-Code>
        get_platform(nc_file),
        get_reporting_id(nc_file)
    )

    exit(0)


if __name__ == '__main__':
    # read filename from command line
    if len(sys.argv) < 3:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    function = sys.argv[1]
    nc_file = sys.argv[2]

    globals()[function](nc_file)
