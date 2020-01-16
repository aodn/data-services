"""
Returns the relative path to create for a modified SOOP TRV created by SOOP-TRV.py

author Laurent Besnard, laurent.besnard@utas.edu.au
"""

import re

from netCDF4 import Dataset


def get_main_soop_trv_var(netcdf_file_path):
    netcdf_file_obj = Dataset(netcdf_file_path, mode='r')
    variables       = netcdf_file_obj.variables.keys()
    netcdf_file_obj.close()

    if 'CPHL' in variables:
        return 'CPHL'
    elif 'TEMP' in variables:
        return 'TEMP'
    elif 'PSAL' in variables:
        return 'PSAL'
    elif 'TURB' in variables:
        return 'TURB'


def get_main_var_folder_name(netcdf_file_path):
    main_var = get_main_soop_trv_var(netcdf_file_path)

    if main_var == 'CPHL':
        return 'chlorophyll'
    elif main_var == 'TEMP':
        return 'temperature'
    elif main_var == 'PSAL':
        return 'salinity'
    elif main_var == 'TURB':
        return 'turbidity'


def remove_creation_date_from_filename(netcdf_filename):
    return re.sub('_C-.*$', '.nc', netcdf_filename)
