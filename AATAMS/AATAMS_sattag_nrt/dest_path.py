#!/usr/bin/env python3
"""
Returns the relative path of a AATAMS NRT NetCDF file
author Laurent Besnard, laurent.besnard@utas.edu.au
"""

import os
import sys

from netCDF4 import Dataset


def create_file_hierarchy(netcdf_file_path):
    netcdf_file_obj = Dataset(netcdf_file_path, mode='r')
    platform_code   = netcdf_file_obj.platform_code
    instance_len    = netcdf_file_obj.variables['INSTANCE'].ndim
    netcdf_file_obj.close()

    # handle individual profiles and aggregated ones
    if instance_len == 1:
        relative_netcdf_path = os.path.join('AATAMS', 'AATAMS_sattag_nrt', \
                                            platform_code, 'profiles', \
                                            os.path.basename(netcdf_file_path))
    else:
        relative_netcdf_path = os.path.join('AATAMS', 'AATAMS_sattag_nrt', \
                                            platform_code, \
                                            os.path.basename(netcdf_file_path))

    return relative_netcdf_path


if __name__ == '__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    destination_path = create_file_hierarchy(sys.argv[1])

    if not destination_path:
        exit(1)

    print(destination_path)
    exit(0)
