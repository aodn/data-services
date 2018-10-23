import datetime

import numpy as np
import pandas as pd
from netCDF4 import Dataset, date2num

from generate_netcdf_att import generate_netcdf_att
from util import get_git_revision_script_url
from .common import *
from .qld_data_parser import retrieve_json_data
from .qld_metadata import get_last_modification_date_resource_id, param_mapping_parser

logger = logging.getLogger(__name__)


def generate_qld_netcdf(resource_id, metadata, output_path):
    """
    generate a netcdf file (wave or current) for a resource_id
    :param resource_id:
    :param metadata:
    :param output_path:
    :return:
    """
    last_mod_date = get_last_modification_date_resource_id(metadata['package_name'], resource_id)
    if last_mod_date == None:
        # creating an epoch date
        last_mod_date = datetime.datetime(1970, 1, 1, 0, 0)

    wave_df = retrieve_json_data(resource_id)
    if wave_df is None:
        logger.error('No valid data to process for resource_id {resource_id}'.format(resource_id=resource_id))
        return

    if 'Current Speed' in wave_df.columns.values or 'Current Direction' in wave_df.columns.values:
        logger.info('Processing Current data')
        data_code = 'V'
    else:
        logger.info('Processing Wave data')
        data_code = 'W'

    var_mapping = param_mapping_parser(QLD_WAVE_PARAMETER_MAPPING)
    date_start_str = wave_df.index.strftime('%Y%m%dT%H%M%SZ').values.min()
    date_end_str = wave_df.index.strftime('%Y%m%dT%H%M%SZ').values.max()
    nc_file_name = 'DES-QLD_{data_code}_{date_start}_{deployment_code}_WAVERIDER_FV01_END-{date_end}.nc'.format(
        date_start=date_start_str,
        data_code=data_code,
        deployment_code=metadata['site_name'].replace(' ', '-'),
        date_end=date_end_str)

    nc_file_path = os.path.join(output_path, nc_file_name)
    logger.info('Creating NetCDF {netcdf} from resource_id {resource_id}'.format(
        netcdf=os.path.basename(nc_file_path),
        resource_id=resource_id))

    with Dataset(nc_file_path, 'w', format='NETCDF4') as nc_file_obj:
        nc_file_obj.createDimension("TIME", wave_df.index.shape[0])

        nc_file_obj.createVariable("LATITUDE", "d", fill_value=FILLVALUE)
        nc_file_obj.createVariable("LONGITUDE", "d", fill_value=FILLVALUE)
        nc_file_obj.createVariable("TIMESERIES", "i")
        nc_file_obj["LATITUDE"][:] = metadata['latitude']
        nc_file_obj["LONGITUDE"][:] = metadata['longitude']

        nc_file_obj["TIMESERIES"][:] = 1
        var_time = nc_file_obj.createVariable("TIME", "d", "TIME")
        # add gatts and variable attributes as stored in config files
        generate_netcdf_att(nc_file_obj, NC_ATT_CONFIG, conf_file_point_of_truth=True)
        time_val_dateobj = date2num(wave_df.index.to_pydatetime(), var_time.units, var_time.calendar)

        var_time[:] = time_val_dateobj

        df_varname_ls = list(wave_df[wave_df.keys()].columns.values)

        for df_varname in df_varname_ls:
            df_varname_mapped_equivalent = df_varname
            mapped_varname = var_mapping.loc[df_varname_mapped_equivalent]['VARNAME']

            dtype = wave_df[df_varname].values.dtype
            if dtype == np.dtype('int64'):
                dtype = np.dtype('int16')  # short
            else:
                dtype = np.dtype('f')

            nc_file_obj.createVariable(mapped_varname, dtype, "TIME", fill_value=FILLVALUE)
            set_var_attr(nc_file_obj, var_mapping, mapped_varname, df_varname_mapped_equivalent, dtype)
            setattr(nc_file_obj[mapped_varname], 'coordinates', "TIME LATITUDE LONGITUDE")

            try:
                nc_file_obj[mapped_varname][:] = wave_df[df_varname].values
            except ValueError:
                pass

        setattr(nc_file_obj, 'operator', metadata['owner'])
        setattr(nc_file_obj, 'title', 'Delayed mode wave data measured at {site}'.format(site=metadata['site_name']))
        setattr(nc_file_obj, 'site_code', metadata['site_code'])
        setattr(nc_file_obj, 'site_name', metadata['site_name'])
        if not np.isnan(metadata['wmo_id']):
            setattr(nc_file_obj, 'wmo_id', int(metadata['wmo_id']))

        setattr(nc_file_obj, 'geospatial_lat_min', metadata['latitude'])
        setattr(nc_file_obj, 'geospatial_lat_max', metadata['latitude'])
        setattr(nc_file_obj, 'geospatial_lon_min', metadata['longitude'])
        setattr(nc_file_obj, 'geospatial_lon_max', metadata['longitude'])
        setattr(nc_file_obj, 'time_coverage_start', wave_df.index.strftime('%Y-%m-%dT%H:%M:%SZ').values.min())
        setattr(nc_file_obj, 'time_coverage_end', wave_df.index.strftime('%Y-%m-%dT%H:%M:%SZ').values.max())
        setattr(nc_file_obj, 'date_created', pd.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"))



        data_url = '{base_url_data}{id}&limit={limit}'.format(base_url_data=BASE_URL_DATA,
                                                              id=resource_id,
                                                              limit=LIMIT_VALUES)
        setattr(nc_file_obj, 'data_original_url', data_url)
        setattr(nc_file_obj, 'glossary', 'https://www.qld.gov.au/environment/coasts-waterways/beach/waves-glossary')
        setattr(nc_file_obj, 'wave_monitoring_faq', 'https://www.qld.gov.au/environment/coasts-waterways/beach/waves')
        setattr(nc_file_obj, 'first_deployment_date', metadata.first_deployment_date.strftime("%Y-%m-%dT%H:%M:%SZ"))
        setattr(nc_file_obj, 'water_depth', metadata.water_depth)
        setattr(nc_file_obj, 'water_depth_units', 'meters')
        setattr(nc_file_obj, 'site_information_url', metadata.source_url)
        setattr(nc_file_obj, 'owner', metadata.owner)
        setattr(nc_file_obj, 'instrument_model', metadata.instrument_model)
        setattr(nc_file_obj, 'instrument_maker', metadata.instrument_maker)
        setattr(nc_file_obj, 'waverider_type', metadata.waverider_type)

        github_comment = 'Product created with %s' % get_git_revision_script_url(os.path.realpath(__file__))
        nc_file_obj.lineage = ('%s %s' % (getattr(nc_file_obj, 'lineage', ''), github_comment))

        # save to pickle file the new last downloaded date for future run
        pickle_file = os.path.join(WIP_DIR, 'last_downloaded_date_resource_id.pickle')
        last_downloaded_date_resources = load_pickle_db(pickle_file)
        if not last_downloaded_date_resources:
            last_downloaded_date_resources = dict()
        last_modification = last_mod_date

        last_downloaded_date_resources[resource_id] = last_modification
        with open(pickle_file, 'wb') as p_write:
            pickle.dump(last_downloaded_date_resources, p_write)

        return nc_file_path


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

    if not pd.isnull(var_mapping.loc[df_varname_mapped_equivalent]['COMMENT']):
        setattr(nc_file_obj[nc_varname], 'comment', var_mapping.loc[df_varname_mapped_equivalent]['COMMENT'])

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
