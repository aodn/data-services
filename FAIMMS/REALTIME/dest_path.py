"""
Returns the relative path of a FAIMMS NetCDF file
author Laurent Besnard, laurent.besnard@utas.edu.au
"""

import re

from netCDF4 import Dataset

from aims_realtime_util import get_main_netcdf_var


def get_main_var_folder_name(netcdf_file_path):
    main_var        = get_main_netcdf_var(netcdf_file_path)
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
    elif 'MRY' in site_code or 'MYR' in site_code:
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
