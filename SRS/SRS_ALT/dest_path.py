#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys
from netCDF4 import Dataset


def create_file_hierarchy(netcdf_file_path):
    srs_alt_dir     = os.path.join('SRS', 'ALTIMETRY', 'calibration_validation')
    netcdf_file_obj = Dataset(netcdf_file_path, mode='r')
    site_code       = netcdf_file_obj.site_code
    instrument      = netcdf_file_obj.instrument
    netcdf_file_obj.close()

    if instrument == 'SBE37':
        product_type = 'CTD_timeseries'
    elif instrument == 'SBE26':
        product_type = 'Pressure_gauge'
    elif instrument == 'Aquad':
        product_type = 'Velocity'
    else:
        return None

    netcdf_filename      = os.path.basename(netcdf_file_path)
    relative_netcdf_path = os.path.join(srs_alt_dir, site_code, product_type,
                                        netcdf_filename)

    return relative_netcdf_path

if __name__ == '__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    destination_path = create_file_hierarchy(sys.argv[1])

    if not destination_path:
        exit(1)

    print destination_path
    exit(0)
