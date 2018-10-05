import datetime
import logging
import os
import re

import numpy as np
import pandas as pd
from netCDF4 import Dataset, date2num

from common_awac import ls_txt_files, param_mapping_parser, NC_ATT_CONFIG, set_glob_attr, set_var_attr
from generate_netcdf_att import generate_netcdf_att

logger = logging.getLogger(__name__)

WAVE_PARAMETER_MAPPING = os.path.join(os.path.dirname(__file__), 'wave_parameters_mapping.csv')
VARYING_VAR_LIST = {'Total_Tp_Dirn', 'Total_Tm_Dirn',
                    'Swell_Tp_Dirn', 'Swell_Tm_Dirn',
                    'Sea_Tp_Dirn', 'Sea_Tm_Dirn'}

VALID_WAVE_METHODS_DEF = {'PUV': 'PUV wave direction method using the seabed pressure and component wave velocities',
                          'SUV': 'SUV wave direction method using the surface track and component wave velocities',
                          'MLM': 'MLM wave direction method using the Maximum Likelihood Method with seabed pressure',
                          'MLMST': 'MLMST wave direction method using the Maximum Likelihood Method with surface track'
                          }


def wave_data_parser(filepath):
    """
    parser of wave data file
    :param filepath: txt file path of AWAC wave data
    :return: pandas dataframe of data, pandas dataframe of data metadata
    """
    # parse wave file and merge into datetime object Date and Time columns
    df = pd.read_table(filepath, sep=r"\s*",
                       skiprows=10, parse_dates={'datetime': ['Date', 'Time']},
                       date_parser=lambda x:pd.datetime.strptime(x, '%d/%m/%Y %H:%M'),
                       engine='python')

    if type(df['Hmax'][0]) == np.str:
        logger.error("{file} has missing data column".format(file=filepath))
        return

    """ variables names are on two different lines. Renaming each group of
    variable to add the Total, Swell or Sea suffix """
    matching_tot_cols = [s for s in df.columns
                         if ".1" not in s
                         and ".2" not in s
                         and "Hmax" not in s
                         and "T_Hmax" not in s
                         and "QA" not in s
                         and "datetime" not in s]

    rename_tot_cols = ['Total_{var}'.format(var=x) for x in matching_tot_cols]
    rename_tot_var_dic = dict(zip(matching_tot_cols, rename_tot_cols))

    # Swell
    matching_swell_cols = [s for s in df.columns if ".1" in s]
    rename_swell_cols = [x.strip('.1') for x in matching_swell_cols]
    rename_swell_cols = ['Swell_{var}'.format(var=x) for x in rename_swell_cols]
    rename_swell_var_dic = dict(zip(matching_swell_cols, rename_swell_cols))

    # Sea
    matching_sea_cols = [s for s in df.columns if ".2" in s]
    rename_sea_cols = [x.strip('.2') for x in matching_sea_cols]
    rename_sea_cols = ['Sea_{var}'.format(var=x) for x in rename_sea_cols]
    rename_sea_var_dic = dict(zip(matching_sea_cols, rename_sea_cols))

    # rename all columns
    df.rename(columns=rename_tot_var_dic, inplace=True)
    df.rename(columns=rename_swell_var_dic, inplace=True)
    df.rename(columns=rename_sea_var_dic, inplace=True)

    # substract 8 hours from timezone to be in UTC
    df['datetime'] = df['datetime'].dt.tz_localize(None).astype('O').values - datetime.timedelta(hours=8)

    # retrieve metadata info
    location = pd.read_csv(filepath, sep=r":", skiprows=[0, 2], nrows=1, header=None).values[0][1].strip()

    wave_method_str = pd.read_csv(filepath, skiprows=[0, 1], nrows=1, header=None).values[0][1].strip()
    wave_method_pattern = 'Periods and Directions \(by ({valid_wave_methods_str})\)'.\
        format(valid_wave_methods_str=('|'.join(VALID_WAVE_METHODS_DEF.keys())))
    wave_pattern_match = re.match(re.compile(wave_method_pattern), wave_method_str)

    if wave_pattern_match:
        wave_method = wave_pattern_match.group(1)
        if wave_method not in VALID_WAVE_METHODS_DEF.keys():
            logger.error('Not valid wave method')
    else:
        logger.error('Not valid wave method')

    return df, {'deployment': location,
                'method': wave_method}


def merge_wave_methods(deployment_path):
    """
    Read the different WAVE methods files (usually VALID_WAVE_METHODS_DEF) and combining non varying variables and
    varying variables. A suffix '{WAVE_METHOD}_' is added to the dataframe varnames of varying variables
    :param deployment_path:
    :return: pandas dataframe combining all wave methods files into one dataframe.
    """
    wave_folder_path = os.path.join(deployment_path, "WAVE")
    data_wave_file_ls = ls_txt_files(wave_folder_path)

    missing_file_warn_str = 'No WAVE data files available in {path}'.format(path=deployment_path)
    if not data_wave_file_ls:
        logger.warning(missing_file_warn_str)
        return None
    elif "Waves" not in data_wave_file_ls[0]:
        logger.warning(missing_file_warn_str)
        return None

    # read all wave files/methods, add the method as the keys() to differentiate them
    wave_data = {}
    for data_wave_file in data_wave_file_ls:
        df, df_metadata = wave_data_parser(data_wave_file)
        wave_method = df_metadata['method']
        wave_data[wave_method] = df

    """ as part of the merging of the different wave methods, we need to check that the values of all non changing
    variables are actually not changing"""
    list_var = list(wave_data[wave_data.keys()[0]].columns.values)
    non_varying_var_ls = list(set(list_var) - set(VARYING_VAR_LIST))

    wave_data_combined = pd.DataFrame()
    for i_key in range(len(wave_data.keys()) - 1):
        for var in non_varying_var_ls:
            if not all(wave_data[wave_data.keys()[i_key]][var] == wave_data[wave_data.keys()[i_key + 1]][var]):
                logger.error('{var} is not equal across {wave_method_1} and {wave_method_2} wave files'.format(
                    var=var,
                    wave_method_1=wave_data[wave_data.keys()[i_key]],
                    wave_method_2=wave_data[wave_data.keys()[i_key + 1]]
                )
                )

    """ if ValueError not raised, all non varying variables were checked to be equal"""
    for var in non_varying_var_ls:
        wave_data_combined[var] = wave_data[wave_data.keys()[0]][var]

    for var in VARYING_VAR_LIST:
        for wave_method in wave_data.keys():
            var_method = '{method}_{var}'.format(method=wave_method, var=var)
            wave_data_combined[var_method] = wave_data[wave_method][var]

    return wave_data_combined


def gen_nc_wave_deployment(deployment_path, metadata, site_info,  output_path='/tmp'):
    """
    generate a FV01 NetCDF file combining all wave direction calculation methods into one.
    :param deployment_path: the path to a wave deployment (as defined in metadata txt file)
    :param metadata: metadata output from metadata_parser function
    :param output_path: NetCDF file output path
    :return: output file path
    """
    wave_data_combined = merge_wave_methods(deployment_path)
    if wave_data_combined is None:
        logger.warning('No WAVE data to combined {path}'.format(path=deployment_path))
        return None

    var_mapping = param_mapping_parser(WAVE_PARAMETER_MAPPING)
    deployment_code = os.path.basename(os.path.normpath(deployment_path))
    metadata[1]['deployment_code'] = deployment_code
    site_code = os.path.basename(os.path.dirname(deployment_path)).split('_')[0]

    nc_file_name = 'DOT_WA_W_{date_start}_{site_code}_AWAC-WAVE_FV01_END-{date_end}.nc'.format(
        date_start=wave_data_combined.datetime.dt.strftime('%Y%m%dT%H%M%SZ').values.min(),
        site_code=site_code,
        date_end=wave_data_combined.datetime.dt.strftime('%Y%m%dT%H%M%SZ').values.max()
    )
    nc_file_path = os.path.join(output_path, nc_file_name)

    with Dataset(nc_file_path, 'w', format='NETCDF4') as nc_file_obj:
        nc_file_obj.createDimension("TIME", wave_data_combined.datetime.shape[0])

        nc_file_obj.createVariable("LATITUDE", "d", fill_value=99999.)
        nc_file_obj.createVariable("LONGITUDE", "d", fill_value=99999.)
        nc_file_obj.createVariable("TIMESERIES", "i")
        nc_file_obj["LATITUDE"][:] = metadata[1]['lat_lon'][0]
        nc_file_obj["LONGITUDE"][:] = metadata[1]['lat_lon'][1]
        nc_file_obj["TIMESERIES"][:] = 1

        var_time = nc_file_obj.createVariable("TIME", "d", "TIME")

        # add gatts and variable attributes as stored in config files
        generate_netcdf_att(nc_file_obj, NC_ATT_CONFIG, conf_file_point_of_truth=True)

        time_val_dateobj = date2num(wave_data_combined.datetime.astype('O'), var_time.units, var_time.calendar)
        var_time[:] = time_val_dateobj

        df_varname_ls = list(wave_data_combined[wave_data_combined.keys()].columns.values)
        df_varname_ls.remove("QA")
        df_varname_ls.remove("datetime")

        for df_varname in df_varname_ls:

            is_wave_method = False
            if df_varname in var_mapping.index.values.tolist():
                """ scenario for non varying parameters not depending of wave method"""
                df_varname_mapped_equivalent = df_varname
                mapped_varname = var_mapping.loc[df_varname_mapped_equivalent]['VARNAME']

            elif df_varname.split('_', 1)[0] in VALID_WAVE_METHODS_DEF.keys():
                """ scenario for varying parameters depending of wave method"""
                is_wave_method = True

                wave_method = df_varname.split('_', 1)[0]
                varname = df_varname.split('_', 1)[1]

                df_varname_mapped_equivalent = df_varname.split('_', 1)[1]
                mapped_varname = '{wave_method}_{NC_VARNAME}'.format(wave_method=wave_method,
                                                                 NC_VARNAME=var_mapping.loc[varname].values[0])

            dtype = wave_data_combined[df_varname].values.dtype
            if dtype == np.dtype('int64'):
                dtype = np.dtype('int16')  # short
            else:
                dtype = np.dtype('f')

            nc_file_obj.createVariable(mapped_varname, dtype, "TIME")
            setattr(nc_file_obj[mapped_varname], 'coordinates', "TIME LATITUDE LONGITUDE")
            set_var_attr(nc_file_obj, var_mapping, mapped_varname, df_varname_mapped_equivalent, dtype)
            nc_file_obj[mapped_varname][:] = wave_data_combined[df_varname].values

            if is_wave_method:
                setattr(nc_file_obj[mapped_varname], 'data_method', VALID_WAVE_METHODS_DEF[wave_method])

        # global attributes from metadata txt file
        set_glob_attr(nc_file_obj, wave_data_combined, metadata, site_info)
    return nc_file_path
