"""
Returns the relative path of a ANMN NRS NetCDF file
author Laurent Besnard, laurent.besnard@utas.edu.au
"""

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


def get_anmn_nrs_site_name(netcdf_file_path):
    with Dataset(netcdf_file_path, mode='r') as netcdf_file_obj:
        return netcdf_file_obj.site_code
