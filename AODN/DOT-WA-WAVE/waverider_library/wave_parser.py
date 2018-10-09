import datetime
import logging
import os
import re

import numpy as np
import pandas as pd
from netCDF4 import Dataset, date2num

from common_waverider import ls_txt_files, param_mapping_parser, NC_ATT_CONFIG, set_var_attr, set_glob_attr
from generate_netcdf_att import generate_netcdf_att

logger = logging.getLogger(__name__)

WAVE_PARAMETER_MAPPING = os.path.join(os.path.dirname(__file__), 'wave_parameters_mapping.csv')


def wave_data_parser(data_filepath):
    """
    parser of wave data file
    :param data_filepath: txt file path of datawell waverider data
    :return: pandas dataframe of data, pandas dataframe of data metadata
    """
    # parse wave file
    df = pd.read_excel(data_filepath, parse_dates=False, options={'remove_timezone': True})
    for row in range(10):
        for col in range(10):
            if df.iat[row, col] == 'Hs' or df.iat[row, col] == 'Hs(m)':
                row_start = row + 1
                break

    # find the order of the line above row_start for Total Swell Sea compulsory variables
    try:
        m = re.match('.*(swell).*', ','.join(np.array(df.loc[row_start - 2].values).astype(str)), re.IGNORECASE)
        swell_start_idx = m.span(1)[0]

        m = re.match('.*(sea).*', ','.join(np.array(df.loc[row_start - 2].values).astype(str)), re.IGNORECASE)
        sea_start_idx = m.span(1)[0]

        m = re.match('.*(total).*', ','.join(np.array(df.loc[row_start - 2].values).astype(str)), re.IGNORECASE)
        total_start_idx = m.span(1)[0]
    except:
        logger.error('Standard Swell Sea and Total variable not found. Process abort')
        raise ValueError

    m = re.match('.*(temp).*', ','.join(np.array(df.loc[row_start - 2].values).astype(str)), re.IGNORECASE)
    if m is not None:
        temp_start_idx = m.span(1)[0]
        logger.info('Temperature data available')

    unsorted_var_order = [swell_start_idx, sea_start_idx, total_start_idx]
    unsorted_var_name_order = ['Swell', 'Sea', 'Total']
    indices_sorted_var = [index for index, value in sorted(enumerate(unsorted_var_order), key=lambda x: x[1]) if value > 1][:4]

    df = df.loc[row_start:]  # skip header
    df.dropna(axis=1, how='all', inplace=True)  # remove empty columns
    df.dropna(inplace=True)
    if 'Time' in df.iloc[0].values or '(sec)' in df.iloc[0].values or '(s)' in df.iloc[0].values or '(M)' in df.iloc[0].values:
        df = df.loc[row_start + 1:]  # skip lines we have in various files. row_start is the index of the row. So we still need it

    # Tm and T1 are the same variables aka mean period
    if len(df.columns) == 12:
        new_columns_names = ['datetime',
                             '{type}_Hs'.format(type=unsorted_var_name_order[indices_sorted_var[0]]),
                             '{type}_Tp'.format(type=unsorted_var_name_order[indices_sorted_var[0]]),
                             '{type}_Tm'.format(type=unsorted_var_name_order[indices_sorted_var[0]]),

                             '{type}_Hs'.format(type=unsorted_var_name_order[indices_sorted_var[1]]),
                             '{type}_Tp'.format(type=unsorted_var_name_order[indices_sorted_var[1]]),
                             '{type}_Tm'.format(type=unsorted_var_name_order[indices_sorted_var[1]]),
                             '{type}_Dir'.format(type=unsorted_var_name_order[indices_sorted_var[1]]),

                             '{type}_Hs'.format(type=unsorted_var_name_order[indices_sorted_var[2]]),
                             '{type}_Tp'.format(type=unsorted_var_name_order[indices_sorted_var[2]]),
                             '{type}_Tm'.format(type=unsorted_var_name_order[indices_sorted_var[2]]),
                             '{type}_Dir'.format(type=unsorted_var_name_order[indices_sorted_var[2]])
                             ]

    elif len(df.columns) == 13:
        if [temp_start_idx] > unsorted_var_order:
            new_columns_names = ['datetime',
                                 '{type}_Hs'.format(type=unsorted_var_name_order[indices_sorted_var[0]]),
                                 '{type}_Tp'.format(type=unsorted_var_name_order[indices_sorted_var[0]]),
                                 '{type}_Tm'.format(type=unsorted_var_name_order[indices_sorted_var[0]]),

                                 '{type}_Hs'.format(type=unsorted_var_name_order[indices_sorted_var[1]]),
                                 '{type}_Tp'.format(type=unsorted_var_name_order[indices_sorted_var[1]]),
                                 '{type}_Tm'.format(type=unsorted_var_name_order[indices_sorted_var[1]]),
                                 '{type}_Dir'.format(type=unsorted_var_name_order[indices_sorted_var[1]]),

                                 '{type}_Hs'.format(type=unsorted_var_name_order[indices_sorted_var[2]]),
                                 '{type}_Tp'.format(type=unsorted_var_name_order[indices_sorted_var[2]]),
                                 '{type}_Tm'.format(type=unsorted_var_name_order[indices_sorted_var[2]]),
                                 '{type}_Dir'.format(type=unsorted_var_name_order[indices_sorted_var[2]]),

                                 'Temp'
                                 ]
    elif len(df.columns) == 10:
        new_columns_names = ['datetime',
                             '{type}_Hs'.format(type=unsorted_var_name_order[indices_sorted_var[0]]),
                             '{type}_Tp'.format(type=unsorted_var_name_order[indices_sorted_var[0]]),
                             '{type}_Tm'.format(type=unsorted_var_name_order[indices_sorted_var[0]]),

                             '{type}_Hs'.format(type=unsorted_var_name_order[indices_sorted_var[1]]),
                             '{type}_Tp'.format(type=unsorted_var_name_order[indices_sorted_var[1]]),
                             '{type}_Tm'.format(type=unsorted_var_name_order[indices_sorted_var[1]]),

                             '{type}_Hs'.format(type=unsorted_var_name_order[indices_sorted_var[2]]),
                             '{type}_Tp'.format(type=unsorted_var_name_order[indices_sorted_var[2]]),
                             '{type}_Tm'.format(type=unsorted_var_name_order[indices_sorted_var[2]]),
                             ]
    else:
        logger.error('Unknown data header format')
        raise ValueError

    df.columns = new_columns_names
    df = df.dropna()
    try:
        df['datetime'] = pd.to_datetime(df['datetime'], format='%d/%m/%Y %H:%M', utc=True)  #need to include timezone
    except:
        logger.warning('different time format')

    # substract 8 hours from timezone to be in UTC
    metadata = retrieve_data_metadata(data_filepath, df)
    df['datetime'] = df['datetime'].dt.tz_localize(None).astype('O').values - \
                     datetime.timedelta(hours=metadata['TIMEZONE'])

    return df, metadata


def metadata_parser(filepath):
    """
    parse metadata from metadata text file
    :param filepath:
    :return:
    """
    df = pd.read_csv(filepath, sep=r": ", skiprows=0,
                     skipinitialspace=True,
                     header=None,
                     engine='python')
    df.loc['DATE_START'] = pd.to_datetime(df.loc['DATA AVAILABLE FROM'], format='%d/%m/%Y', utc=True)
    df.loc['DATE_END'] = pd.to_datetime(df.loc['DATA AVAILABLE TO'], format='%d/%m/%Y', utc=True)
    df.loc['LATITUDE'] = df.loc['LATITUDE'].apply(pd.to_numeric)
    df.loc['LONGITUDE'] = df.loc['LONGITUDE'].apply(pd.to_numeric)

    if 'AWST' in df.loc['INSTRUMENT TIMEFRAME'].values[0]:
        df.loc['TIMEZONE'] = 8

    return df


def retrieve_data_metadata(data_filepath, data):
    """
    Looking for the metadata file which matches the data file by using the dates in both as there is a lack of
    information in the data file
    :param data_filepath: path of the data file we're trying the match a metadata file with
    :param data: pandas df of data_filepath
    :return: dictionary of metadata file
    """
    date_start_data = data['datetime'].values.min()
    date_end_data = data['datetime'].values.max()

    # we scroll through all the different metadata files to find the one where the start and end date match
    metadata_dir_path = os.path.dirname(os.path.dirname(data_filepath))
    ls_metadata = ls_txt_files(metadata_dir_path)
    for metadata_file_path in ls_metadata:
        metadata = metadata_parser(metadata_file_path)
        if date_start_data >= np.datetime64(metadata.loc['DATE_START'].values[0]) - np.timedelta64(1, 'D') and \
                date_end_data <= np.datetime64(metadata.loc['DATE_END'].values[0]) + np.timedelta64(1, 'D'):
            deployment_code = os.path.basename(metadata_file_path).split('_')[0]
            metadata.loc['DEPLOYMENT CODE'] = deployment_code
            return metadata.to_dict()[0]


def gen_nc_wave_deployment(data_file_path, site_info, output_path):
    """
    create a FV01 waverider NetCDF file
    :param data_file_path:
    :param site_info:
    :param output_path:
    :return:
    """
    logger.info('Processing {filepath} from {site_url}.'.format(filepath=data_file_path,
                                                                site_url=site_info['data_zip_url']))
    wave_data, metadata = wave_data_parser(data_file_path)

    if metadata is None:
        logger.warning('No metadata file found for {data_filename} from {site_url} '.
                       format(data_filename=os.path.basename(data_file_path),
                              site_url=site_info['data_zip_url']))
        return None

    site_code = site_info['site_code']
    metadata['SITE CODE'] = site_code
    metadata['SITE NAME'] = site_info['site_name']

    var_mapping = param_mapping_parser(WAVE_PARAMETER_MAPPING)
    nc_file_name = 'DOT_WA_W_{date_start}_{site_code}-WAVERIDER_FV01_END-{date_end}.nc'.format(
        date_start=wave_data.datetime.dt.strftime('%Y%m%dT%H%M%SZ').values.min(),
        site_code=site_code,
        date_end=wave_data.datetime.dt.strftime('%Y%m%dT%H%M%SZ').values.max()
    )
    nc_file_path = os.path.join(output_path, nc_file_name)

    with Dataset(nc_file_path, 'w', format='NETCDF4') as nc_file_obj:
        nc_file_obj.createDimension("TIME", wave_data.datetime.shape[0])

        nc_file_obj.createVariable("LATITUDE", "d", fill_value=99999.)
        nc_file_obj.createVariable("LONGITUDE", "d", fill_value=99999.)
        nc_file_obj.createVariable("TIMESERIES", "i")
        nc_file_obj["LATITUDE"][:] = metadata['LATITUDE']
        nc_file_obj["LONGITUDE"][:] = metadata['LONGITUDE']
        nc_file_obj["TIMESERIES"][:] = 1

        var_time = nc_file_obj.createVariable("TIME", "d", "TIME")

        # add gatts and variable attributes as stored in config files
        generate_netcdf_att(nc_file_obj, NC_ATT_CONFIG, conf_file_point_of_truth=True)

        time_val_dateobj = date2num(wave_data['datetime'].astype('O').values, var_time.units, var_time.calendar)
        var_time[:] = time_val_dateobj

        df_varname_ls = list(wave_data[wave_data.keys()].columns.values)
        df_varname_ls.remove("datetime")

        for df_varname in df_varname_ls:
            df_varname_mapped_equivalent = df_varname
            mapped_varname = var_mapping.loc[df_varname_mapped_equivalent]['VARNAME']

            dtype = wave_data[df_varname].values.dtype
            if dtype == np.dtype('int64'):
                dtype = np.dtype('int16')  # short
            else:
                dtype = np.dtype('f')

            nc_file_obj.createVariable(mapped_varname, dtype, "TIME")
            setattr(nc_file_obj[mapped_varname], 'coordinates', "TIME LATITUDE LONGITUDE")
            set_var_attr(nc_file_obj, var_mapping, mapped_varname, df_varname_mapped_equivalent, dtype)
            nc_file_obj[mapped_varname][:] = wave_data[df_varname].values

        setattr(nc_file_obj, 'original_data_url', site_info['data_zip_url'])
        setattr(nc_file_obj, 'original_metadata_url', site_info['metadata_zip_url'])

        # global attributes from metadata txt file
        set_glob_attr(nc_file_obj, wave_data, metadata)

    return nc_file_path
