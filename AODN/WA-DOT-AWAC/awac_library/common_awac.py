import logging
import os
import re

import pandas as pd
from dateutil import parser

logger = logging.getLogger(__name__)

NC_ATT_CONFIG = os.path.join(os.path.dirname(__file__), 'generate_nc_file_att')


def param_mapping_parser(filepath):
    """
    parser of mapping csv file
    :param filepath: path to csv file containing mapping information between AWAC parameters and IMOS/CF parameters
    :return: pandas dataframe of filepath
    """
    if not filepath:
        logger.error('No PARAMETER MAPPING file available')
        exit(1)

    df = pd.read_table(filepath, sep=r",",
                       engine='python')
    df.set_index('AWAC_VARNAME', inplace=True)
    return df


def metadata_parser(filepath):
    """
    parser of location metadata file
    :param filepath: txt file path of metadata file
    :return: pandas dataframe of data metadata, pandas dataframe of metadata
    """
    df = pd.read_csv(filepath, sep=r"(\s{2})+", skiprows=8,
                     skipinitialspace=True,
                     date_parser=lambda x: pd.datetime.strptime(x, '%d/%m/%Y'),
                     header=None,
                     engine='python')

    # cleaning manually since data.dropna(axis=1, how='all') doesn't work
    # move by 1 the index since using inplace option
    for col_idx in [1, 2, 3, 4, 5]:
        try:
            df.drop(df.columns[col_idx], axis=1, inplace=True)
        except Exception, e:
            logger.info('No comment data in metadata file. {err}'.format(err=e))

    if df.shape[1] == 6:
        df.columns = ['deployment_name', 'start_date', 'end_date', 'instrument_maker', 'instrument_model', 'comment']
    elif df.shape[1] == 5:  # means comment column is empty
        df.columns = ['deployment_name', 'start_date', 'end_date', 'instrument_maker', 'instrument_model']
        df["comment"] = ""

    df.set_index('deployment_name', inplace=True)

    # strip leading/trailing spaces from values
    for col in df.columns:
        df[col] = df[col].str.strip()

    timezone = pd.read_csv(filepath, skiprows=1, nrows=1, header=None)[0][0].strip(
        '#Time Zone: Australian Western Standard Time  (UTC +').rstrip(')')
    timezone = parser.parse(timezone[:]).time()

    lat_lon_str = pd.read_csv(filepath, skiprows=2, nrows=1, header=None)[0][0]
    lat_lon_vals = re.findall(r"[-+]?\d*\.\d+|\d+", pd.read_csv(filepath, skiprows=2, nrows=1, header=None)[0][0])
    lat_lon_vals = [float(s) for s in lat_lon_vals]

    water_depth_str = pd.read_csv(filepath, skiprows=3, nrows=1, header=None)[0][0]
    water_depth_val = re.findall(r"[-+]?\d*\.\d+|\d+", water_depth_str)
    water_depth_val = [float(s) for s in water_depth_val]

    station_name_str = pd.read_csv(filepath, nrows=1, header=None)[0][0].strip('#Station metadata at ')
    site_code = os.path.basename(os.path.normpath(filepath)).split('_')[0]

    return df, {'site_name': station_name_str,
                'site_code' : site_code,
                'water_depth': water_depth_val,
                'lat_lon': lat_lon_vals,
                'timezone': timezone.hour + timezone.minute/60
                }


def ls_txt_files(path):
    """
    list text files from path
    :param path: path to find txt files extension in
    :return: list of txt files
    """
    file_ls = []
    for txt_file in os.listdir(path):
        if txt_file.endswith(".txt"):
            file_ls.append(os.path.join(path, txt_file))

    return file_ls


def set_glob_attr(nc_file_obj, data, metadata, deployment_code):
    """
    Set generic global attributes in netcdf file object
    :param nc_file_obj: NetCDF4 object already opened
    :param data:
    :param metadata:
    :param deployment_code:
    :return:
    """

    setattr(nc_file_obj, 'instrument_maker', metadata[0].loc[deployment_code]['instrument_maker'])
    setattr(nc_file_obj, 'instrument_model', metadata[0].loc[deployment_code]['instrument_model'])
    if metadata[0].loc[deployment_code]['comment']:
        setattr(nc_file_obj, 'comment', metadata[0].loc[deployment_code]['comment'])
    setattr(nc_file_obj, 'deployment_code', deployment_code)
    setattr(nc_file_obj, 'site_code', metadata[1]['site_code'])
    setattr(nc_file_obj, 'site_name', metadata[1]['site_name'])
    setattr(nc_file_obj, 'water_depth', metadata[1]['water_depth'])
    setattr(nc_file_obj, 'geospatial_lat_min', metadata[1]['lat_lon'][0])
    setattr(nc_file_obj, 'geospatial_lat_max', metadata[1]['lat_lon'][0])
    setattr(nc_file_obj, 'geospatial_lon_min', metadata[1]['lat_lon'][1])
    setattr(nc_file_obj, 'geospatial_lon_max', metadata[1]['lat_lon'][1])
    setattr(nc_file_obj, 'time_coverage_start',
            data.datetime.dt.strftime('%Y-%m-%dT%H:%M:%SZ').values.min())
    setattr(nc_file_obj, 'time_coverage_end',
            data.datetime.dt.strftime('%Y-%m-%dT%H:%M:%SZ').values.max())
    setattr(nc_file_obj, 'date_created', pd.datetime.now().strftime("%Y-%m-%dT%H:%M:%SZ"))
    setattr(nc_file_obj, 'local_time_zone', metadata[1]['timezone'])


def set_var_attr(nc_file_obj, var_mapping, nc_varname, df_varname_mapped_equivalent, dtype):
    """
    set variable attributes of an already opened NetCDF file
    :param nc_file_obj:
    :param var_mapping:
    :param nc_varname:
    :param df_varname_mapped_equivalent:
    :param dtype:
    :return:
    """

    setattr(nc_file_obj[nc_varname], 'units', var_mapping.loc[df_varname_mapped_equivalent]['UNITS'])

    if not pd.isnull(var_mapping.loc[df_varname_mapped_equivalent]['LONG_NAME']):
        setattr(nc_file_obj[nc_varname], 'long_name', var_mapping.loc[df_varname_mapped_equivalent]['LONG_NAME'])
    else:
        setattr(nc_file_obj[nc_varname], 'long_name',
                var_mapping.loc[df_varname_mapped_equivalent]['STANDARD_NAME'].replace('_', ' '))

    if not pd.isnull(var_mapping.loc[df_varname_mapped_equivalent]['STANDARD_NAME']):
        setattr(nc_file_obj[nc_varname], 'standard_name', var_mapping.loc[df_varname_mapped_equivalent]['STANDARD_NAME'])

    if not pd.isnull(var_mapping.loc[df_varname_mapped_equivalent]['VALID_MIN']):
        setattr(nc_file_obj[nc_varname], 'valid_min', var_mapping.loc[df_varname_mapped_equivalent]['VALID_MIN'].astype(dtype))

    if not pd.isnull(var_mapping.loc[df_varname_mapped_equivalent]['VALID_MAX']):
        setattr(nc_file_obj[nc_varname], 'valid_max', var_mapping.loc[df_varname_mapped_equivalent]['VALID_MAX'].astype(dtype))

    if not pd.isnull(var_mapping.loc[df_varname_mapped_equivalent]['ANCILLARY_VARIABLES']):
        setattr(nc_file_obj[nc_varname], 'ancillary_variables',
                var_mapping.loc[df_varname_mapped_equivalent]['ANCILLARY_VARIABLES'])

    if not pd.isnull(var_mapping.loc[df_varname_mapped_equivalent]['REFERENCE_DATUM']):
        setattr(nc_file_obj[nc_varname], 'reference_datum',
                var_mapping.loc[df_varname_mapped_equivalent]['REFERENCE_DATUM'])

    if not pd.isnull(var_mapping.loc[df_varname_mapped_equivalent]['POSITIVE']):
        setattr(nc_file_obj[nc_varname], 'positive', var_mapping.loc[df_varname_mapped_equivalent]['POSITIVE'])
