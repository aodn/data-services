#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Returns the relative path of a SSTAARS NetCDF file
"""

import os
import re
import sys

def create_file_hierarchy(netcdf_file_path):
    sstaars_alt_dir = os.path.join('CSIRO', 'Climatology', 'SSTAARS', '2017')
    sstaars_aodn_dir = os.path.join(sstaars_alt_dir, 'AODN-product')
    netcdf_file_name = os.path.basename(netcdf_file_path)

    regex_daily_files = re.compile('SSTAARS_daily_fit_[0-9]{3}\.nc')

    if netcdf_file_name == 'SSTAARS.nc'
        return sstaars_alt_dir
    elif (netcdf_file_name == 'SSTAARS_daily_fit.nc') or re.match(regex_daily_files, netcdf_file_name)
        return sstaars_aodn_dir
    else:
        return None

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
