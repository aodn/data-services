import logging
import os

import pandas as pd

from util import get_git_revision_script_url
logger = logging.getLogger(__name__)

METHOD_COMMENT = """
Waverider buoys contain an accelerometer to measure the vertical acceleration as the buoy moves up and
down with the water surface. By integrating this acceleration with time received from an internal clock, the
Waverider buoy provides an instantaneous reading of relative water level around a 2000cm mean. Similarly,
in a Directional Waverider buoy, separate accelerometers are used to measure the horizontal accelerations
as the buoy moves sideways with the waves.
As wave periods increase, the acceleration caused by a given wave height becomes lower. This decreased
acceleration makes it more difficult for the accelerometer to accurately measure the acceleration, and
therefore the instantaneous water level change caused by longer period waves. Due to this, there is a
natural drop off in the response (accuracy) of a Waverider buoy as wave periods increase, particularly
noticeable with periods greater than 20 seconds.
Conversely, the Waverider buoy in water has a natural frequency around 1 second, causing the buoy to
overestimate the instantaneous wave caused accelerations around this period, and therefore the associated
instantaneous water level changes. This is generally not a major problem as waves in coastal and estuarine
areas usually quickly develop a period of at least 2 seconds.
"""
METADATA_FILE = os.path.join(os.path.dirname(__file__), 'buoys_metadata.csv')


def read_metadata_file():
    """
    reads the METADATA_FILE csv file as a panda dataframe
    :return: panda dataframe of METADATA_FILE
    """
    df = pd.read_csv(METADATA_FILE)
    df.set_index('site_code', inplace=True)
    return df


def ls_ext_files(path, ext):
    """
    list text files from path
    :param path: path to find txt files extension in
    :param ext: file extension string ".txt" ".csv" ...
    :return: list of txt files
    """
    file_ls = []
    for txt_file in os.listdir(path):
        if txt_file.endswith(ext):
            file_ls.append(os.path.join(path, txt_file))

    return file_ls


def param_mapping_parser(filepath):
    """
    parser of mapping csv file
    :param filepath: path to csv file containing mapping information between BOM parameters and IMOS/CF parameters
    :return: pandas dataframe of filepath
    """
    if not filepath:
        logger.error('No PARAMETER MAPPING file available')

    df = pd.read_table(filepath, sep=r",",
                       engine='python')
    df.set_index('BOM_VARNAME', inplace=True)
    return df


def set_glob_attr(nc_file_obj, data, metadata):
    """
    Set generic global attributes in netcdf file object
    :param nc_file_obj: NetCDF4 object already opened
    :param data:
    :param metadata:
    :return:
    """
    setattr(nc_file_obj, 'title', metadata['title'])
    setattr(nc_file_obj, 'site_code', metadata['site_code'])
    setattr(nc_file_obj, 'site_name', metadata['site_name'])
    setattr(nc_file_obj, 'instrument_maker', metadata['instrument_maker'])
    setattr(nc_file_obj, 'instrument_model', metadata['instrument_model'])
    setattr(nc_file_obj, 'waverider_type', metadata['waverider_type'])
    setattr(nc_file_obj, 'water_depth', metadata['water_depth'])
    setattr(nc_file_obj, 'water_depth_units', metadata['water_depth_units'])
    setattr(nc_file_obj, 'wmo_id', metadata['wmo_id'])
    setattr(nc_file_obj, 'geospatial_lat_min', metadata['latitude'])
    setattr(nc_file_obj, 'geospatial_lat_max', metadata['latitude'])
    setattr(nc_file_obj, 'geospatial_lon_min', metadata['longitude'])
    setattr(nc_file_obj, 'geospatial_lon_max', metadata['longitude'])
    setattr(nc_file_obj, 'time_coverage_start',
            data.datetime.dt.strftime('%Y-%m-%dT%H:%M:%SZ').values.min())
    setattr(nc_file_obj, 'time_coverage_end',
            data.datetime.dt.strftime('%Y-%m-%dT%H:%M:%SZ').values.max())
    setattr(nc_file_obj, 'date_created', pd.datetime.now().strftime("%Y-%m-%dT%H:%M:%SZ"))
    setattr(nc_file_obj, 'local_time_zone', metadata['timezone'])
    setattr(nc_file_obj, 'method', METHOD_COMMENT)
    setattr(nc_file_obj, 'original_filename', metadata['original_filename'])

    github_comment = 'Product created with %s' % get_git_revision_script_url(os.path.realpath(__file__))
    nc_file_obj.lineage = ('%s %s' % (getattr(nc_file_obj, 'lineage', ''), github_comment))


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
