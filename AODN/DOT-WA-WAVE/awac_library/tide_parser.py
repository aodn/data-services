import datetime
import logging
import os

import numpy as np
import pandas as pd
from netCDF4 import Dataset, date2num

from common_awac import ls_txt_files, param_mapping_parser, NC_ATT_CONFIG, set_glob_attr, set_var_attr
from generate_netcdf_att import generate_netcdf_att

logger = logging.getLogger(__name__)

TIDE_PARAMETER_MAPPING = os.path.join(os.path.dirname(__file__), 'tide_parameters_mapping.csv')

TIDES_COMMENT = """
Water levels through the deployment period are determined from both Surface Tracking (AST) and from the seabed pressure record.

Typically the AWAC is deployed with wave data recording on the hour and vertical current profiling every 10 minutes. During wave data recording the AWAC records the sea surface as well as the seabed pressure.  During sampling for a vertical current profile the AWAC records the seabed pressure but not the sea surface.

The method used to establish a water level record for the deployment is:
* use the sea surface record during wave recording to establish the water level at that time;
* during wave recording determine the difference between the sea surface and the seabed pressure record;
* during sampling for a vertical current profile use the difference established between the sea surface and the seabed pressure to adjust the seabed pressure to a sea surface record;

The foregoing method uses the assumption that the difference between the sea surface and the seabed pressure determined during wave recording does not significantly vary in the following hour.  Primarily this is assuming that the barometric pressure does not vary significantly during the hour.  This assumption would become less appropriate if wave data sampling were to be undertaken at intervals greater than one hour.

The water levels determined by the foregoing method are reduced to a zero mean for presentation in text files of data.
"""


def tide_data_parser(filepath):
    """
    parser of tide data file
    :param filepath: txt file path of AWAC tide data
    :return: pandas dataframe of data, pandas dataframe of data metadata
    """
    # parse wave file and merge into datetime object Date and Time columns
    df = pd.read_table(filepath, sep=r"\s*",
                       skiprows=8, parse_dates={'datetime': ['Date', 'Time']},
                       date_parser=lambda x:pd.datetime.strptime(x, '%d/%m/%Y %H:%M'),
                       engine='python')

    # rename column
    df.rename(columns={"metre": "water_metre"}, inplace=True)

    # substract 8 hours from timezone to be in UTC
    df['datetime'] = df['datetime'].dt.tz_localize(None).astype('O').values - datetime.timedelta(hours=8)

    # retrieve metadata info
    location = pd.read_csv(filepath, sep=r":", skiprows=[0, 2], nrows=1, header=None).values[0][1].strip()

    return df, {'deployment': location}


def gen_nc_tide_deployment(deployment_path, metadata, output_path='/tmp'):
    """
    generate a FV01 NetCDF file of tidal data.
    :param deployment_path: the path to a tidal deployment (as defined in metadata txt file)
    :param metadata: metadata output from metadata_parser function
    :param output_path: NetCDF file output path
    :return: output file path
    """

    tide_folder_path = os.path.join(deployment_path, "TIDE")
    data_tide_file_ls = ls_txt_files(tide_folder_path)

    missing_file_warn_str = 'No TIDE data files available in {path}'.format(path=deployment_path)
    if not data_tide_file_ls:
        logger.warning(missing_file_warn_str)
        return None
    elif "Water Level" not in data_tide_file_ls[0]:
        logger.warning(missing_file_warn_str)
        return None

    tide_data, tide_metadata = tide_data_parser(data_tide_file_ls[0])  # only one file

    var_mapping = param_mapping_parser(TIDE_PARAMETER_MAPPING)
    deployment_code = os.path.basename(os.path.normpath(deployment_path))
    nc_file_name = 'DOT_WA_Z_{date_start}_{deployment_code}-AWAC-TIDE_FV01_END-{date_end}.nc'.format(
        date_start=tide_data.datetime.dt.strftime('%Y%m%dT%H%M%SZ').values.min(),
        deployment_code=deployment_code,
        date_end=tide_data.datetime.dt.strftime('%Y%m%dT%H%M%SZ').values.max()
    )
    nc_file_path = os.path.join(output_path, nc_file_name)

    with Dataset(nc_file_path, 'w', format='NETCDF4') as nc_file_obj:
        nc_file_obj.createDimension("TIME", tide_data.datetime.shape[0])

        nc_file_obj.createVariable("LATITUDE", "d", fill_value=99999.)
        nc_file_obj.createVariable("LONGITUDE", "d", fill_value=99999.)
        nc_file_obj.createVariable("TIMESERIES", "i")
        nc_file_obj["LATITUDE"][:] = metadata[1]['lat_lon'][0]
        nc_file_obj["LONGITUDE"][:] = metadata[1]['lat_lon'][1]
        nc_file_obj["TIMESERIES"][:] = 1

        var_time = nc_file_obj.createVariable("TIME", "d", "TIME")

        # add gatts and variable attributes as stored in config files
        generate_netcdf_att(nc_file_obj, NC_ATT_CONFIG, conf_file_point_of_truth=True)

        time_val_dateobj = date2num(tide_data.datetime.astype('O'), var_time.units, var_time.calendar)
        var_time[:] = time_val_dateobj

        df_varname_ls = list(tide_data[tide_data.keys()].columns.values)
        df_varname_ls.remove("datetime")

        if df_varname_ls[0] == 'water_metre':
            df_varname = df_varname_ls[0]
            df_varname_mapped_equivalent = df_varname
            mapped_varname = var_mapping.loc[df_varname_mapped_equivalent]['VARNAME']

            dtype = tide_data[df_varname].values.dtype
            if dtype == np.dtype('int64'):
                dtype = np.dtype('int16')  # short
            else:
                dtype = np.dtype('f')

            nc_file_obj.createVariable(mapped_varname, dtype, "TIME")
            setattr(nc_file_obj[mapped_varname], 'coordinates', "TIME LATITUDE LONGITUDE")

            set_var_attr(nc_file_obj, var_mapping, mapped_varname, df_varname_mapped_equivalent, dtype)
            nc_file_obj[mapped_varname][:] = tide_data[df_varname].values
            setattr(nc_file_obj[mapped_varname], 'comment', TIDES_COMMENT)

        # global attributes from metadata txt file
        set_glob_attr(nc_file_obj, tide_data, metadata, deployment_code)

    return nc_file_path
