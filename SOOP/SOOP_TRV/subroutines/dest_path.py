#!/usr/bin/env python
# Returns the relative path to create for a modified SOOP TRV created by SOOP-TRV.py
#
# author Laurent Besnard, laurent.besnard@utas.edu.au
# lat mod: 19/11/2015

import datetime
import os, sys
from netCDF4 import Dataset
import re


def get_main_soop_trv_var(netcdf_file_path):
    netcdf_file_obj = Dataset(netcdf_file_path,  mode='r')
    variables       = netcdf_file_obj.variables.keys()
    netcdf_file_obj.close()

    if   'CPHL' in variables:
        return 'CPHL'
    elif 'TEMP' in variables:
        return 'TEMP'
    elif 'PSAL' in variables:
        return 'PSAL'
    elif 'TURB' in variables:
        return 'TURB'

def get_main_var_folder_name(netcdf_file_path):
    main_var = get_main_soop_trv_var(netcdf_file_path)

    if   main_var == 'CPHL':
        return 'chlorophyll'
    elif main_var == 'TEMP':
        return 'temperature'
    elif main_var == 'PSAL':
        return 'salinity'
    elif main_var == 'TURB':
        return 'turbidity'

#netcdf_file_path='IMOS_SOOP-TRV_T_20151118T141237Z_VNCF_FV01_END-20151119T025006Z_C-20151119T190251_z.nc'
def remove_creation_date_from_filename(netcdf_filename):
    return re.sub('_C-.*$', '.nc', netcdf_filename)

def create_file_hierarchy(netcdf_file_path):
    netcdf_file_obj = Dataset(netcdf_file_path, mode='r')
    ship_code       = netcdf_file_obj.platform_code
    vessel_name     = netcdf_file_obj.vessel_name
    file_version    = netcdf_file_obj.file_version
    main_var_folder = get_main_var_folder_name(netcdf_file_path)

    if file_version == "Level 0 - Raw data":
        level_name = 'noQAQC'
    elif file_version == 'Level 1 - Quality Controlled Data':
        level_name = 'QAQC'

    date_start           = datetime.datetime.strptime(netcdf_file_obj.time_coverage_start, "%Y-%m-%dT%H:%M:%SZ")
    date_start           = date_start.strftime('%Y%m%dT%H%M%SZ')
    date_end             = datetime.datetime.strptime(netcdf_file_obj.time_coverage_end, "%Y-%m-%dT%H:%M:%SZ")
    date_end             = date_end.strftime('%Y%m%dT%H%M%SZ')

    netcdf_filename      = remove_creation_date_from_filename(os.path.basename(netcdf_file_path))
    relative_netcdf_path = os.path.join('SOOP', 'SOOP-TRV', '%s_%s' % (ship_code, vessel_name), 'By_Cruise', 'Cruise_START-%s_END-%s' % (date_start, date_end), main_var_folder, netcdf_filename)

    netcdf_file_obj.close()
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
