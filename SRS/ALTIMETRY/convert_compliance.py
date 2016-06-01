#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Convert Altimetry file to make them compliant with IMOS and CF conventions
"""

import sys
from netCDF4 import Dataset
import os
sys.path.insert(0, os.path.join(os.environ.get('DATA_SERVICES_DIR'), 'lib'))
from python.generate_netcdf_att import generate_netcdf_att


def convert_compliance(netcdf_file):
    netcdf_file_obj = Dataset(netcdf_file, mode='a')
    conf_file       = 'alt_gatts.conf'
    generate_netcdf_att(netcdf_file_obj, conf_file) # create gatts and var atts

    time = netcdf_file_obj.variables['TIME']
    if hasattr(time, 'FillValue_'):
        delattr(time, 'FillValue_')

    if 'DEPTH' in netcdf_file_obj.variables.keys():
        var = netcdf_file_obj.variables['DEPTH']
        netcdf_file_obj.geospatial_vertical_min = min(var[:])
        netcdf_file_obj.geospatial_vertical_max = max(var[:])

    netcdf_file_obj.close()


if __name__ == '__main__':
    convert_compliance(sys.argv[1])
