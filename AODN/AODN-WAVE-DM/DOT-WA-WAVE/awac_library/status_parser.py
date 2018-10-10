import datetime
import logging
import os

import numpy as np
import pandas as pd
from netCDF4 import Dataset, date2num

from common_awac import ls_txt_files, param_mapping_parser, NC_ATT_CONFIG, set_glob_attr, set_var_attr
from generate_netcdf_att import generate_netcdf_att

logger = logging.getLogger(__name__)

STATUS_PARAMETER_MAPPING = os.path.join(os.path.dirname(__file__), 'status_parameters_mapping.csv')


def status_data_parser(filepath):
    """
    parser of status data file
    :param filepath: txt file path of AWAC status data
    :return: pandas dataframe of data, pandas dataframe of data metadata
    """
    # parse wave file and merge into datetime object Date and Time columns
    df = pd.read_table(filepath, sep=r"\s\s*",
                       skiprows=9, parse_dates={'datetime': [0, 1]},
                       date_parser=lambda x: pd.datetime.strptime(x, '%d/%m/%Y %H:%M'),
                       engine='python',
                       names=['date', 'time', 'pressure', 'volt', 'heading', 'pitch', 'roll'], header=None)

    # substract 8 hours from timezone to be in UTC
    df['datetime'] = df['datetime'].dt.tz_localize(None).astype('O').values - datetime.timedelta(hours=8)

    # retrieve metadata info
    location = pd.read_csv(filepath, sep=r":", skiprows=4, nrows=1, header=None).values[0][1].strip()

    return df, {'deployment': location}


def gen_nc_status_deployment(deployment_path, metadata, site_info, output_path='/tmp'):
    """
    generate a FV01 NetCDF file of instrument status data.
    :param deployment_path: the path to a temperature deployment (as defined in metadata txt file)
    :param metadata: metadata output from metadata_parser function
    :param output_path: NetCDF file output path
    :return: output file path
    """

    status_folder_path = os.path.join(deployment_path, "STATUS")
    data_status_file_ls = ls_txt_files(status_folder_path)

    missing_file_warn_str = 'No STATUS data files available in {path}'.format(path=deployment_path)
    if not data_status_file_ls:
        logger.warning(missing_file_warn_str)
        return None
    elif "Status" not in data_status_file_ls[0]:
        logger.warning(missing_file_warn_str)
        return None

    status_data, status_metadata = status_data_parser(data_status_file_ls[0])  # only one file

    var_mapping = param_mapping_parser(STATUS_PARAMETER_MAPPING)
    deployment_code = os.path.basename(deployment_path.split(' ')[0])
    metadata[1]['deployment_code'] = deployment_code
    site_code = metadata[1]['site_code']

    nc_file_name = 'DOT_WA_E_{date_start}_{site_code}_AWAC-STATUS_FV01_END-{date_end}.nc'.format(
        date_start=status_data.datetime.dt.strftime('%Y%m%dT%H%M%SZ').values.min(),
        site_code=site_code,
        date_end=status_data.datetime.dt.strftime('%Y%m%dT%H%M%SZ').values.max()
    )
    nc_file_path = os.path.join(output_path, nc_file_name)

    with Dataset(nc_file_path, 'w', format='NETCDF4') as nc_file_obj:
        nc_file_obj.createDimension("TIME", status_data.datetime.shape[0])

        nc_file_obj.createVariable("LATITUDE", "d", fill_value=99999.)
        nc_file_obj.createVariable("LONGITUDE", "d", fill_value=99999.)
        nc_file_obj.createVariable("NOMINAL_DEPTH", "d", fill_value=99999.)

        nc_file_obj.createVariable("TIMESERIES", "i")
        nc_file_obj["LATITUDE"][:] = metadata[1]['lat_lon'][0]
        nc_file_obj["LONGITUDE"][:] = metadata[1]['lat_lon'][1]
        nc_file_obj["NOMINAL_DEPTH"][:] = metadata[1]['water_depth']

        setattr(nc_file_obj["NOMINAL_DEPTH"], 'standard_name', 'depth')
        setattr(nc_file_obj["NOMINAL_DEPTH"], 'long_name', 'nominal_depth')
        setattr(nc_file_obj["NOMINAL_DEPTH"], 'units', 'metres')
        setattr(nc_file_obj["NOMINAL_DEPTH"], 'positive', 'down')
        setattr(nc_file_obj["NOMINAL_DEPTH"], 'axis', 'Z')
        setattr(nc_file_obj["NOMINAL_DEPTH"], 'reference_datum', 'sea surface')
        setattr(nc_file_obj["NOMINAL_DEPTH"], 'valid_min', -5.)
        setattr(nc_file_obj["NOMINAL_DEPTH"], 'valid_max', 40.)
        setattr(nc_file_obj["NOMINAL_DEPTH"], 'axis', 'Z')

        nc_file_obj["TIMESERIES"][:] = 1

        var_time = nc_file_obj.createVariable("TIME", "d", "TIME")

        # add gatts and variable attributes as stored in config files
        generate_netcdf_att(nc_file_obj, NC_ATT_CONFIG, conf_file_point_of_truth=True)

        time_val_dateobj = date2num(status_data.datetime.astype('O'), var_time.units, var_time.calendar)
        var_time[:] = time_val_dateobj

        df_varname_ls = list(status_data[status_data.keys()].columns.values)
        df_varname_ls.remove("datetime")

        for df_varname in df_varname_ls:
            df_varname_mapped_equivalent = df_varname
            mapped_varname = var_mapping.loc[df_varname_mapped_equivalent]['VARNAME']

            dtype = status_data[df_varname].values.dtype
            if dtype == np.dtype('int64'):
                dtype = np.dtype('int16')  # short
            else:
                dtype = np.dtype('f')

            nc_file_obj.createVariable(mapped_varname, dtype, "TIME")

            setattr(nc_file_obj[mapped_varname], 'coordinates', "TIME LATITUDE LONGITUDE NOMINAL_DEPTH")
            set_var_attr(nc_file_obj, var_mapping, mapped_varname, df_varname_mapped_equivalent, dtype)

            nc_file_obj[mapped_varname][:] = status_data[df_varname].values

        # global attributes from metadata txt file
        set_glob_attr(nc_file_obj, status_data, metadata, site_info)

    return nc_file_path
