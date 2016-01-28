#!/usr/bin/env python
"""
Returns the relative path of a FAIMMS NetCDF file
author Laurent Besnard, laurent.besnard@utas.edu.au
"""

import datetime
import os, sys
from netCDF4 import Dataset, num2date
import re

def get_main_faimms_var(netcdf_file_path):
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
    main_var        = get_main_faimms_var(netcdf_file_path)
    netcdf_file_obj = Dataset(netcdf_file_path, mode='r')
    var_folder_name = netcdf_file_obj.variables[main_var].long_name.replace(' ','_')
    aims_channel_id = netcdf_file_obj.aims_channel_id

    if hasattr(netcdf_file_obj.variables[main_var], 'sensor_depth'):
        sensor_depth    = netcdf_file_obj.variables[main_var].sensor_depth
        retval          = '%s@%sm_channel_%s' %(var_folder_name, str(sensor_depth), str(aims_channel_id))
    else:
        retval          = '%s_channel_%s' %(var_folder_name, str(aims_channel_id))

    netcdf_file_obj.close()
    return retval

def get_faimms_site_name(netcdf_file_path):
    netcdf_file_obj = Dataset(netcdf_file_path, mode='r')
    site_code       = netcdf_file_obj.site_code
    netcdf_file_obj.close()

    if 'DAV' in site_code:
        return 'Davies_Reef'
    elif 'OI' in site_code:
        return 'Orpheus_Island'
    elif 'OTI' in site_code:
        return 'One_Tree_Island'
    elif 'RIB' in site_code:
        return 'Rib_Reef'
    elif 'MYR' in site_code:
        return 'Myrmidon_Reef'
    elif 'LIZ' in site_code:
        return 'Lizard_Island'
    elif 'HI' in site_code:
        return 'Heron_Island'
    else:
        return []

def get_faimms_platform_type(netcdf_file_path):
    netcdf_file_obj = Dataset(netcdf_file_path, mode='r')
    site_code       = netcdf_file_obj.site_code
    netcdf_file_obj.close()

    if 'SF' in site_code:
        site_code_number = re.findall(r'\d+', site_code)
        return 'Sensor_Float_%s' % str(site_code_number[0])
    elif 'RP' in site_code:
        site_code_number = re.findall(r'\d+', site_code)
        return 'Relay_Pole_%s' % str(site_code_number[0])
    elif 'BSE' in site_code or 'WS' in site_code:
        return 'Weather_Station_Platform'
    else:
        return []

def get_main_faimms_site_name_path(netcdf_file_path):
    site_name     = get_faimms_site_name(netcdf_file_path)
    platform_type = get_faimms_platform_type(netcdf_file_path)

    if site_name == []:
        print >>sys.stderr, 'Unknown site name'
        exit(1)

    if platform_type == []:
        print >>sys.stderr, 'Unknown platform type'
        exit(1)

    return os.path.join(site_name, platform_type)

def remove_md5_from_filename(netcdf_filename):
    return re.sub('.nc.*$', '.nc', netcdf_filename)

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

    site_name_path       = get_main_faimms_site_name_path(netcdf_file_path)
    netcdf_filename      = remove_md5_from_filename(os.path.basename(netcdf_file_path))
    relative_netcdf_path = os.path.join('FAIMMS', site_name_path, main_var_folder, year, level_name, netcdf_filename)

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
