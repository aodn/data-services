#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Returns the relative path of a ANMN NRS NetCDF file
author Laurent Besnard, laurent.besnard@utas.edu.au
"""

import os
import re
import sys

from netCDF4 import Dataset


def get_main_anmn_nrs_var(netcdf_file_path):
    netcdf_file_obj = Dataset(netcdf_file_path, mode='r')
    variables       = netcdf_file_obj.variables.keys()
    netcdf_file_obj.close()

    del variables[variables.index('TIME')]
    del variables[variables.index('LATITUDE')]
    del variables[variables.index('LONGITUDE')]

    if 'NOMINAL_DEPTH' in variables:
        del variables[variables.index('NOMINAL_DEPTH')]

    qc_var = [s for s in variables if '_quality_control' in s]
    if qc_var != []:
        del variables[variables.index(qc_var[0])]

    return variables[0]

def get_main_var_folder_name(netcdf_file_path):
    main_var        = get_main_anmn_nrs_var(netcdf_file_path)
    netcdf_file_obj = Dataset(netcdf_file_path, mode='r')
    var_folder_name = netcdf_file_obj.variables[main_var].long_name.replace(' ', '_')
    aims_channel_id = netcdf_file_obj.aims_channel_id

    if hasattr(netcdf_file_obj.variables[main_var], 'sensor_depth'):
        sensor_depth    = netcdf_file_obj.variables[main_var].sensor_depth
        retval          = '%s@%sm_channel_%s' % (var_folder_name, str(sensor_depth), str(aims_channel_id))
    else:
        retval          = '%s_channel_%s' % (var_folder_name, str(aims_channel_id))

    netcdf_file_obj.close()
    return retval

def get_anmn_nrs_site_name(netcdf_file_path):
    netcdf_file_obj = Dataset(netcdf_file_path, mode='r')
    site_code       = netcdf_file_obj.site_code
    netcdf_file_obj.close()

    return site_code

def remove_md5_from_filename(netcdf_filename):
    return re.sub('.nc.*$', '.nc', netcdf_filename)

def add_site_code_to_filename(netcdf_filename, site_code):
    return re.sub('(?=[^0-9]{6})Z_.*_FV0', 'Z_%s_FV0' % site_code, netcdf_filename)

def create_file_hierarchy(netcdf_file_path):
    netcdf_file_obj = Dataset(netcdf_file_path, mode='r')
    file_version    = netcdf_file_obj.file_version
    main_var_folder = get_main_var_folder_name(netcdf_file_path)

    if file_version == "Level 0 - Raw data":
        level_name = 'NO_QAQC'
    elif file_version == 'Level 1 - Quality Controlled Data':
        level_name = 'QAQC'

    year                 = netcdf_file_obj.time_coverage_start[0:4]
    netcdf_file_obj.close()

    site_code            = get_anmn_nrs_site_name(netcdf_file_path)
    netcdf_filename      = remove_md5_from_filename(os.path.basename(netcdf_file_path))
    netcdf_filename      = add_site_code_to_filename(netcdf_filename, site_code)
    relative_netcdf_path = os.path.join('ANMN', 'NRS', 'REAL_TIME', site_code, main_var_folder, year, level_name, netcdf_filename)

    return relative_netcdf_path

if __name__== '__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    destination_path = create_file_hierarchy(sys.argv[1])

    if not destination_path:
        exit(1)

    print destination_path
    exit(0)
