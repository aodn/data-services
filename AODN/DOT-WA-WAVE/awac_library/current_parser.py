import datetime
import glob
import logging
import os
import re

import numpy as np
import pandas as pd
from netCDF4 import Dataset, date2num

from common_awac import param_mapping_parser, NC_ATT_CONFIG, set_glob_attr, set_var_attr
from generate_netcdf_att import generate_netcdf_att

logger = logging.getLogger(__name__)

CURRENT_PARAMETER_MAPPING = os.path.join(os.path.dirname(__file__), 'current_parameters_mapping.csv')

CURRENT_COMMENT = """
Two Current text files are produced.
The Current text file names are a combination of the Location Name and the Deployment Name selected via the "Process Nortek WPR File" menu option together with either
Currents Bottom Up, or,
Currents Surface Down,

The current cells in the "Currents Bottom Up" text file are listed with the seabed as the datum and would be appropriate to seabed sediment drift investigations.
The current cells in the "Currents Surface Down" text file are listed with the sea surface as the datum and would be appropriate to surface drift investigations.
NetCDF files are generated using the "Bottom Up" files.
"""


def current_data_parser(filepath):
    """
    parser of current data file
    :param filepath: txt file path of AWAC tide data
    :return: pandas dataframe of data, pandas dataframe of data metadata
    """
    # parse current file and merge into datetime object Date and Time columns
    df = pd.read_table(filepath, sep=r"\s*",
                       skiprows=15, parse_dates={'datetime': ['Date', 'Time']},
                       date_parser=lambda x:pd.datetime.strptime(x, '%d/%m/%Y %H:%M'),
                       engine='python')

    # rename column
    df.rename(columns={"m": "water_height"}, inplace=True)
    df.rename(columns={"Vel": "Vel_average"}, inplace=True)
    df.rename(columns={"Dir": "Dir_average"}, inplace=True)

    # substract 8 hours from timezone to be in UTC
    df['datetime'] = df['datetime'].dt.tz_localize(None).astype('O').values - datetime.timedelta(hours=8)

    # retrieve metadata info
    location = pd.read_csv(filepath, sep=r":", skiprows=4, nrows=1, header=None).values[0][1].strip()
    n_cells = pd.read_csv(filepath, sep=r":", skiprows=7, nrows=1, header=None).values[0][1]
    cell_size = pd.read_csv(filepath, sep=r":", skiprows=8, nrows=1, header=None).values[0][1].strip()
    blanking_distance = pd.read_csv(filepath, sep=r":", skiprows=9, nrows=1, header=None).values[0][1].strip()

    return df, {'deployment': location,
                'number_of_cells': n_cells,
                'cell_size': cell_size,
                'blanking_distance': blanking_distance}


def gen_nc_current_deployment(deployment_path, metadata, output_path='/tmp'):
    """
    generate a FV01 NetCDF file of current data.
    :param deployment_path: the path to a tidal deployment (as defined in metadata txt file)
    :param metadata: metadata output from metadata_parser function
    :param output_path: NetCDF file output path
    :return: output file path
    """

    current_folder_path = os.path.join(deployment_path, "CURRENT")
    data_current_file_ls = glob.glob('{current_folder_path}/*Bottom Up.txt'.format(
        current_folder_path=current_folder_path))

    missing_file_warn_str = 'No CURRENT data files available in {path}'.format(path=deployment_path)
    if not data_current_file_ls:
        logger.warning(missing_file_warn_str)
        return None

    current_data, current_metadata = current_data_parser(data_current_file_ls[0])  # only one file

    var_mapping = param_mapping_parser(CURRENT_PARAMETER_MAPPING)
    deployment_code = os.path.basename(os.path.normpath(deployment_path))
    nc_file_name = 'DOT_WA_ZV_{date_start}_{deployment_code}-AWAC-CURRENT_FV01_END-{date_end}.nc'.format(
        date_start=current_data.datetime.dt.strftime('%Y%m%dT%H%M%SZ').values.min(),
        deployment_code=deployment_code,
        date_end=current_data.datetime.dt.strftime('%Y%m%dT%H%M%SZ').values.max()
    )
    nc_file_path = os.path.join(output_path, nc_file_name)

    with Dataset(nc_file_path, 'w', format='NETCDF4') as nc_file_obj:
        nc_file_obj.createDimension("TIME", current_data.datetime.shape[0])

        nc_file_obj.createVariable("LATITUDE", "d", fill_value=99999.)
        nc_file_obj.createVariable("LONGITUDE", "d", fill_value=99999.)
        nc_file_obj.createVariable("TIMESERIES", "i")
        nc_file_obj["LATITUDE"][:] = metadata[1]['lat_lon'][0]
        nc_file_obj["LONGITUDE"][:] = metadata[1]['lat_lon'][1]
        nc_file_obj["TIMESERIES"][:] = 1

        var_time = nc_file_obj.createVariable("TIME", "d", "TIME")

        # add gatts and variable attributes as stored in config files
        generate_netcdf_att(nc_file_obj, NC_ATT_CONFIG, conf_file_point_of_truth=True)

        time_val_dateobj = date2num(current_data.datetime.astype('O'), var_time.units, var_time.calendar)
        var_time[:] = time_val_dateobj

        df_varname_ls = list(current_data[current_data.keys()].columns.values)
        df_varname_ls.remove("datetime")

        current_cell_varname_pattern = re.compile(r"""(?P<varname>Dir|Vel)\.(?P<cell_number>[0-9].*)""")
        for df_varname in df_varname_ls:
            is_var_current_cell = False
            is_var_current_average_cell = False
            if current_cell_varname_pattern.match(df_varname):
                fields = current_cell_varname_pattern.match(df_varname)
                df_varname_mapped_equivalent = fields.group('varname')
                mapped_varname = '{varname}_CELL_{cell_number}'.format(
                    varname=var_mapping.loc[df_varname_mapped_equivalent]['VARNAME'],
                    cell_number=fields.group('cell_number'))
                is_var_current_cell = True

            elif df_varname.endswith('_average'):
                df_varname_mapped_equivalent = df_varname.split('_')[0]
                mapped_varname = '{varname}_AVERAGE'.format(
                    varname=var_mapping.loc[df_varname_mapped_equivalent]['VARNAME'])
                is_var_current_average_cell = True
            else:
                df_varname_mapped_equivalent = df_varname
                mapped_varname = var_mapping.loc[df_varname_mapped_equivalent]['VARNAME']

            dtype = current_data[df_varname].values.dtype
            if dtype == np.dtype('int64'):
                dtype = np.dtype('int16')  # short
            else:
                dtype = np.dtype('f')

            nc_file_obj.createVariable(mapped_varname, dtype, "TIME")
            set_var_attr(nc_file_obj, var_mapping, mapped_varname, df_varname_mapped_equivalent, dtype)
            if not mapped_varname == 'DEPTH':
                setattr(nc_file_obj[mapped_varname], 'coordinates', "TIME LATITUDE LONGITUDE DEPTH")

            if is_var_current_cell:
                setattr(nc_file_obj[mapped_varname], 'cell_order', 'from sea bottom to top')
                setattr(nc_file_obj[mapped_varname], 'cell_number', fields.group('cell_number'))
                setattr(nc_file_obj[mapped_varname], 'cell_size',  current_metadata['cell_size'])
                setattr(nc_file_obj[mapped_varname], 'total_number_of_cells',  current_metadata['number_of_cells'])
                setattr(nc_file_obj[mapped_varname], 'blanking_distance_between_cells',  current_metadata['blanking_distance'])
            if is_var_current_average_cell:
                setattr(nc_file_obj[mapped_varname], 'cell_comment', 'cell at depth average')

            nc_file_obj[mapped_varname][:] = current_data[df_varname].values

        # global attributes from metadata txt file
        setattr(nc_file_obj, 'data_info', CURRENT_COMMENT)
        setattr(nc_file_obj, 'number_of_cells', str(current_metadata['number_of_cells']))
        setattr(nc_file_obj, 'cell_size', current_metadata['cell_size'])
        setattr(nc_file_obj, 'blanking_distance', current_metadata['blanking_distance'])

        set_glob_attr(nc_file_obj, current_data, metadata, deployment_code)

    return nc_file_path
