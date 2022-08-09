"""
wave_parser.py -> specific functions to parse a waverider data file.

 * wave_data_parser(data_filepath) -> parse a yearly xls, xlsx file.
 * metadata_parser(filepath)       -> parse a metadata file. Returns a pandas df
 * retrieve_data_metadata          -> look for the metadata file associated with the data file
 * gen_nc_wave_deployment          -> generate a NetCDF file

"""
import datetime
import logging
import os
import re
import sys
import shutil
import tempfile

import numpy as np
import pandas as pd
from netCDF4 import Dataset, date2num, stringtochar

from .common_waverider import ls_txt_files, param_mapping_parser, NC_ATT_CONFIG, set_var_attr, set_glob_attr
from python.generate_netcdf_att import generate_netcdf_att

logger = logging.getLogger(__name__)

WAVE_PARAMETER_MAPPING = os.path.join(os.path.dirname(__file__), 'wave_parameters_mapping.csv')


def wave_data_parser_txt(data_filepath):
    """
    parser of wave data excel file
    :param data_filepath: file path of datawell waverider data
    :return: pandas dataframe of data, pandas dataframe of data metadata
    """
    # parse wave file
    colspecs = [[0, 17], [17, 25], [25, 31], [31, 38], [38, 43], [43, 50], [50, 55], [55, 61], [61, 67],
                [67, 74], [74, 80], [80, 86], [86, 92], [92, 99], [99, 104], [104, 111], [111, 117],
                [117, 126], [126, 132], [132, 140]]

    df = pd.read_fwf(data_filepath,
                     colspecs=colspecs,
                     skiprows=20,
                     engine='python',
                     error_bad_lines=False)

    df.columns.values[0] = 'ix'  # rename first unnamed column to ix
    df['datetime'] = pd.to_datetime(df.ix[:], format='%Y%m%d %H%M', errors='coerce', utc=True)
    df = df[~df.datetime.isnull()]  # to remove datetime == NaT
    df.index = df.datetime
    df = df.apply(pd.to_numeric, errors='coerce')
    df.datetime = df.index  # reconverting datetime to time after line above

    df = df[~df.datetime.isnull()]  # to remove datetime == NaT
    df.index = df.datetime

    df.dropna(axis=1, how='all', inplace=True)  # remove empty columns
    df.dropna(inplace=True)  # remove rows full of NaN

    # we check the columns are similar across all text files:"
    if df.columns.values.tolist() == ['Period', 'Hs', 'Tp', 'Tz', 'Tm', 'Hs.1', 'Tp.1', 'Tz.1', 'Tm.1', 'Hs.2', 'Tp.2',
                                      'Tz.2', 'Tm.2', 'Hs.3', 'Ts', 'Hmax', 'THmax', 'Hs.4', 'Tz.3', 'datetime']:
        new_columns_names = ['Period',
                             '{type}_Hs'.format(type='Total'),
                             '{type}_Tp'.format(type='Total'),
                             '{type}_Tz'.format(type='Total'),
                             '{type}_Tm'.format(type='Total'),

                             '{type}_Hs'.format(type='Swell'),
                             '{type}_Tp'.format(type='Swell'),
                             '{type}_Tz'.format(type='Swell'),
                             '{type}_Tm'.format(type='Swell'),

                             '{type}_Hs'.format(type='Sea'),
                             '{type}_Tp'.format(type='Sea'),
                             '{type}_Tz'.format(type='Sea'),
                             '{type}_Tm'.format(type='Sea'),

                             '{type}_Hs'.format(type='Wave'),
                             '{type}_Ts'.format(type='Wave'),
                             '{type}_Hmax'.format(type='Wave'),
                             '{type}_THmax'.format(type='Wave'),

                             '{type}_Hs'.format(type='TuckerDraper'),
                             '{type}_Tz'.format(type='TuckerDraper'),
                             'datetime'
                             ]
        df.columns = new_columns_names

    else:
        logger.error('Unknown data header format')
        raise ValueError

    df = df.dropna()
    # we are excluding these variables for now until we know their definition
    df.drop(['Period',
             '{type}_Hs'.format(type='TuckerDraper'),
             '{type}_Tz'.format(type='TuckerDraper'),
             '{type}_Hs'.format(type='Wave'),
             '{type}_Ts'.format(type='Wave'),
             '{type}_Hmax'.format(type='Wave'),
             '{type}_THmax'.format(type='Wave')
             ], axis=1, inplace=True)

    # substract 8 hours from timezone to be in UTC
    metadata = retrieve_data_metadata(data_filepath, df)  # looking for matching metadata
    try:
        df['datetime'] = df['datetime'].dt.tz_localize(None).astype('O').values - \
                         datetime.timedelta(hours=metadata['TIMEZONE'])
    except:
        df['datetime'] = df['datetime'].dt.tz_localize(None).astype('O').values - \
                         datetime.timedelta(hours=8)

    return df, metadata


def wave_data_parser_excel(data_filepath):
    """
    parser of wave data excel file
    :param data_filepath: file path of datawell waverider data
    :return: pandas dataframe of data, pandas dataframe of data metadata
    """
    # parse wave file
    try:
        df = pd.read_excel(data_filepath, parse_dates=False, engine='openpyxl')
        logger.warning('openpyxl does not support the old .xls file format. Using xlrd to read this file')
    except:
        try:
            df = pd.read_excel(data_filepath, parse_dates=False, engine='xlrd')
        except:
            logger.error('openpyxl and xlrd could not read this file')
            raise ValueError

    """
    looking for the line where the data starts. We assume we should find at least Hs or Hs(m), and withing the first 10
    rows to be faster
    """
    for row in range(10):
        for col in range(10):
            if df.iat[row, col] == 'Hs' or df.iat[row, col] == 'Hs(m)':
                row_start = row + 1
                break

    """
    The order of Swell, Sea and Total wave parameters is not stored the same way in all xls, xlsx files. We're looking
    for the order. This information is usually on the line above row_start.
    We expect to find all those 3 names. If not, we raise an error don't process the file.
    """
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

    """In some case we have temperature logger data. It seems to only be the case when we have 13 columns"""
    m = re.match('.*(temp).*', ','.join(np.array(df.loc[row_start - 2].values).astype(str)), re.IGNORECASE)
    if m is not None:
        temp_start_idx = m.span(1)[0]
        logger.info('Temperature data available')

    unsorted_var_order = [swell_start_idx, sea_start_idx, total_start_idx]
    unsorted_var_name_order = ['Swell', 'Sea', 'Total']
    indices_sorted_var = [index for index, value in sorted(enumerate(unsorted_var_order),
                                                           key=lambda x: x[1]) if value > 1][:4]

    df = df.loc[row_start:]  # we rewrite the dataframe by skipping the header
    df.dropna(axis=1, how='all', inplace=True)  # remove empty columns
    df.dropna(inplace=True)  # remove rows full of NaN

    # In some files, we still have the first line containing variable metadata. We check this and drop this line from df
    if 'Time' in df.iloc[0].values or '(sec)' in df.iloc[0].values or '(s)' in df.iloc[0].values or '(M)' in df.iloc[
        0].values:
        df = df.loc[row_start + 1:]

    # Tm and T1 are the same variables aka mean period
    """ the next part could be approached in a better, clever and more robust way. {type} corresponds to either Sea,
    Total or Swell. Then we assume the order of Hs, Tp or Tm(also T1) to be always in the same order. This should be
    checked though. Depending of the number of columns, we have noted different variables available. Again, this could
    be checked
    """
    filename_no_ext = os.path.splitext(os.path.basename(data_filepath))[0]

    if len(df.columns) == 12 and filename_no_ext.endswith('_Z'):
        # directional (*_Z.* filename)
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

    elif len(df.columns) == 13 and filename_no_ext.endswith('_Z'):
        # directional (*_Z.* filename)
        # we check that the temp variable is indeed the last one in the dataframe
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

    elif len(df.columns) == 10 or filename_no_ext.endswith('_L'):
        # non directional (*_L.* filename)
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
        df['datetime'] = pd.to_datetime(df['datetime'], format='%d/%m/%Y %H:%M', utc=True)  # local time
    except:
        logger.warning('different time format')

    # substract 8 hours from timezone to be in UTC
    metadata = retrieve_data_metadata(data_filepath, df)  # looking for matching metadata
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
    df.loc['LATITUDE'] = float(df.loc['LATITUDE'][0].split(' ')[0])
    df.loc['LONGITUDE'] = float(df.loc['LONGITUDE'][0].split(' ')[0])

    if 'AWST' in df.loc['INSTRUMENT TIMEFRAME'].values[0]:
        df.loc['TIMEZONE'] = 8
    else:
        logger.error('Unknown Time zone. Manual debug required')
        raise ValueError

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
    for metadata_filepath in ls_metadata:
        metadata = metadata_parser(metadata_filepath)

        """ we check that the time values of the data is within the time range deployment information found in the
        metadata within more or less a day"""
        if date_start_data >= np.datetime64(metadata.loc['DATE_START'].values[0]) - np.timedelta64(1, 'D') and \
                date_end_data <= np.datetime64(metadata.loc['DATE_END'].values[0]) + np.timedelta64(1, 'D'):
            deployment_code = os.path.basename(metadata_filepath).split('_')[0]
            metadata.loc['DEPLOYMENT CODE'] = deployment_code

            return metadata.to_dict()[0]


def gen_nc_wave_deployment(data_filepath, site_info, output_path):
    """
    create a FV01 waverider NetCDF file
    :param data_filepath: path of the data file to process
    :param site_info: site information as found from the kml file
    :param output_path:
    :return:
    """
    logger.info('Processing {filepath} from {site_url}.'.format(filepath=data_filepath,
                                                                site_url=site_info['data_zip_url']))
    if data_filepath.endswith('xls') or data_filepath.endswith('xlsx'):
        wave_data, metadata = wave_data_parser_excel(data_filepath)
    else:
        wave_data, metadata = wave_data_parser_txt(data_filepath)

    if metadata is None:
        logger.error('No metadata file found for {data_filename} from {site_url} '.
                     format(data_filename=os.path.basename(data_filepath),
                            site_url=site_info['data_zip_url']))
        raise Exception

    site_code = site_info['site_code']
    site_name = site_info['site_name']

    # adding site_info information into metadata to be used in set_glob_attr function
    metadata['SITE CODE'] = site_code
    metadata['SITE NAME'] = site_info['site_name']

    var_mapping = param_mapping_parser(WAVE_PARAMETER_MAPPING)
    site_name = site_name.replace(' ', '-')
    nc_file_name = 'DOT-WA_{date_start}_{site_name}_DM_WAVE-PARAMETERS_END-{date_end}.nc'.format(
        date_start=wave_data.datetime.dt.strftime('%Y%m%dT%H%M%SZ').values.min(),
        site_name=site_name,
        date_end=wave_data.datetime.dt.strftime('%Y%m%dT%H%M%SZ').values.max()
    )

    temp_dir = tempfile.mkdtemp()
    nc_file_path = os.path.join(temp_dir, nc_file_name)

    try:
        with Dataset(nc_file_path, 'w', format='NETCDF4') as nc_file_obj:
            nc_file_obj.createDimension("TIME", wave_data.datetime.shape[0])
            # nc_file_obj.createDimension("station_id_strlen", 30)

            var_time = nc_file_obj.createVariable("TIME", "d", "TIME")
            nc_file_obj.createVariable("LATITUDE", "d", fill_value=99999.)
            nc_file_obj.createVariable("LONGITUDE", "d", fill_value=99999.)
            # nc_file_obj.createVariable("WAVE_quality_control", "b", fill_value=127)

            nc_file_obj["LATITUDE"][:] = metadata['LATITUDE']
            nc_file_obj["LONGITUDE"][:] = metadata['LONGITUDE']

            # add gatts and variable attributes as stored in config files
            generate_netcdf_att(nc_file_obj, NC_ATT_CONFIG, conf_file_point_of_truth=True)

            time_val_dateobj = date2num(wave_data['datetime'].astype('O').values, var_time.units, var_time.calendar)
            var_time[:] = time_val_dateobj

            df_varname_ls = list(wave_data[list(wave_data.keys())].columns.values)
            df_varname_ls.remove("datetime")
            df_varname_ls.remove("Sea_Hs")
            df_varname_ls.remove("Sea_Tp")
            df_varname_ls.remove("Sea_Tm")
            # df_varname_ls.remove("Sea_Tz")
            df_varname_ls.remove("Swell_Hs")
            df_varname_ls.remove("Swell_Tp")
            df_varname_ls.remove("Swell_Tm")
            if "Sea_Dir" in df_varname_ls:
                df_varname_ls.remove("Sea_Dir")
            if "Swell_Dir" in df_varname_ls:
                df_varname_ls.remove("Swell_Dir")
            # df_varname_ls.remove("Swell_Tz")
            # df_varname_ls.remove("RMS_Hrms")
            # df_varname_ls.remove("RMS_Tmax")
            # df_varname_ls.remove("RMS_Tz")
            # df_varname_ls.remove("10_H10")
            # df_varname_ls.remove("10_Tmax")

            for df_varname in df_varname_ls:
                df_varname_mapped_equivalent = df_varname
                # TODO: blocked by https://github.com/aodn/data-services/issues/1061
                mapped_varname = var_mapping.loc[df_varname_mapped_equivalent]['VARNAME']
                if type(mapped_varname) != str:
                    logger.error("More than one mapped varname for {varname}."
                                 "Please fix issue in the var mapping file".format(varname=df_varname))
                    raise Exception

                dtype = wave_data[df_varname].values.dtype
                if dtype == np.dtype('int64'):
                    dtype = np.dtype('int16')  # short
                else:
                    dtype = np.dtype('f')

                nc_file_obj.createVariable(mapped_varname, dtype, "TIME")
                set_var_attr(nc_file_obj, var_mapping, mapped_varname, df_varname_mapped_equivalent, dtype)
                setattr(nc_file_obj[mapped_varname], 'coordinates', "TIME LATITUDE LONGITUDE")
                setattr(nc_file_obj[mapped_varname], 'ancillary_variable', "WAVE_quality_control")
                # setattr(nc_file_obj[mapped_varname], 'ancillary_variable', "TEMP_quality_control")

                nc_file_obj[mapped_varname][:] = wave_data[df_varname].values

            # global attributes from metadata txt file
            set_glob_attr(nc_file_obj, wave_data, metadata)

            # adding gatts of where the data comes from
            # FIX IT TO ADD THIS INFO IN ABSTRACT:
            setattr(nc_file_obj, 'original_data_url', site_info['data_zip_url'])
            setattr(nc_file_obj, 'original_metadata_url', site_info['metadata_zip_url'])

        # we do this for pipeline v2
        os.chmod(nc_file_path, 0o664)
        shutil.move(nc_file_path, output_path)

    except Exception as err:
        exc_type, exc_obj, exc_tb = sys.exc_info()
        logger.error(err)

    shutil.rmtree(temp_dir)

    if 'exc_obj' not in locals():
        return nc_file_path
    else:
        raise Exception
