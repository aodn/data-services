import datetime
import json
import logging
import os
import tempfile

import pandas
from aodntools.ncwriter import ImosTemplate
from . import config
from .lookup import lookup_get_nc_template, lookup_get_aodn_variable
from jsonmerge import merge
from netCDF4 import date2num
from netCDF4 import num2date, Dataset
from pkg_resources import resource_filename

LOGGER = logging.getLogger(__name__)

SOURCES_METADATA_FILENAME = config.sources_metadata_filename


def convert_wave_data_to_netcdf(api_config_path, nc_template_path, df, output_dir):
    """
    convert a pandas dataframe into an IMOS compliant NetCDF files

        Parameters:
            nc_template_path: path of a json NetCDF template to write NetCDF file
            df (pandas dataframe): dataframe of WAVE data
            source_metadata (pandas dataframe): metadata information
            output_dir (string): absolute path of path to write NetCDF files

        Returns:
            path (string): NetCDF file path
    """
    template = ImosTemplate.from_json(nc_template_path)
    for df_variable_name in df.columns.values:
        aodn_variable_name = lookup_get_aodn_variable(api_config_path, df_variable_name)
        if aodn_variable_name == "TIME":
            time_val_dateobj = date2num(df.timestamp,
                                        template.variables['TIME']['units'],
                                        template.variables['TIME']['calendar'])

            template.variables['TIME']['_data'] = time_val_dateobj

        elif aodn_variable_name is not None:
            template.variables[aodn_variable_name]['_data'] = df[df_variable_name].values

    template.add_extent_attributes()
    template.add_date_created_attribute()

    template.global_attributes.update({
        'featureType': 'timeSeries',
        'history': "{date_created}: file created".format(
            date_created=datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'))
    })

    month_start = datetime.datetime(df.timestamp.min().year, df.timestamp.min().month, 1, 0, 0, 0)
    output_nc_filename = '{institution_code}_W_{site_code}_{date_start}_monthly_FV00.nc'.format(
        institution_code=template.global_attributes['institution_code'].upper(),
        site_code=template.global_attributes['site_code'].upper(),
        date_start=datetime.datetime.strftime(month_start, '%Y%m%dT%H%M%SZ')
    )

    netcdf_path = os.path.join(output_dir, output_nc_filename)
    template.to_netcdf(netcdf_path)

    return netcdf_path


def merge_source_institution_json_template(api_config_path, source_id):
    """
    Merging source_id specific NetCDF template with its affiliated institution generic NetCDF template.
    the source_id template will overwrite key values if similar keys are found in both templates
    """

    institution_template_path = lookup_get_nc_template(api_config_path, source_id)
    with open(institution_template_path) as f:
        institution_template_json_data = json.load(f)

    source_template_path = os.path.join(api_config_path, SOURCES_METADATA_FILENAME)
    if not os.path.exists(source_template_path):
        source_template_path = resource_filename("ardc_nrt", source_template_path)

    with open(source_template_path) as f:
        sources_template_json_data = json.load(f)

    source_id_template_json_data = sources_template_json_data[source_id]

    return merge_json_data_to_file(institution_template_json_data, source_id_template_json_data)


def merge_json_data_to_file(json_original_data, json_to_merge_data):
    merge_json = merge(json_original_data, json_to_merge_data)
    json_tmp_file = tempfile.mktemp()
    with open(json_tmp_file, "w") as file:
        json.dump(merge_json, file, indent=2, sort_keys=True)

    return json_tmp_file


def nc_get_max_timestamp(nc_path):
    """
    Returns the max value of the TIME variable in a NetCDF file

        Parameters:
            nc_path (string): NetCDF absolute path

        Returns:
            Pandas timestamp: Max timestamp (date at UTC) of TIME variable
    """
    with Dataset(nc_path) as nc_obj:
        cf_time_obj = num2date(nc_obj["TIME"][:].max(), nc_obj["TIME"].units, nc_obj["TIME"].calendar)

        val = pandas.Timestamp(year=cf_time_obj.year,
                               month=cf_time_obj.month,
                               day=cf_time_obj.day,
                               hour=cf_time_obj.hour,
                               minute=cf_time_obj.minute,
                               second=cf_time_obj.second,
                               tz='UTC')

        return val
