#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys
from netCDF4 import Dataset


def create_file_hierarchy(netcdf_file_path):
    aatams_meop_dir     = os.path.join('AATAMS', 'satellite_tagging', 'MEOP_QC_CTD')
    netcdf_file_obj = Dataset(netcdf_file_path, mode='r')
    deployment_code = netcdf_file_obj.deployment_code
    netcdf_file_obj.close()

    netcdf_filename      = os.path.basename(netcdf_file_path)
    relative_netcdf_path = os.path.join(aatams_meop_dir, deployment_code,
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
