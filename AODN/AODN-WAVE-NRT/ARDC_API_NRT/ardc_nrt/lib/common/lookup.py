import datetime
import json
import logging
import os

import pandas

from pkg_resources import resource_filename

from . import config as config_main

LOGGER = logging.getLogger(__name__)

SOURCES_METADATA_FILENAME = config_main.sources_metadata_filename
VARIABLES_LOOKUP_FILENAME = config_main.variables_lookup_filename


def lookup_get_sources_id_metadata(api_config_path):
    """
    Return a pandas dataframe containing all the source_id 's metadata written in
    config/[API]/[SOURCES_METADATA_FILENAME]

    Parameters:
        api_config_path (string): api config path (SOFAR, OMC ...)

    Returns:
        (pandas Dataframe): containing all source_id's metadata
    """
    file_path = os.path.join(api_config_path, SOURCES_METADATA_FILENAME)
    if not os.path.exists(file_path):
        file_path = resource_filename("ardc_nrt",
                                      file_path)

    df = pandas.read_json(file_path)

    return df


def lookup_get_source_id_metadata(api_config_path, source_id):
    """
    Return a pandas dataframe containing a source_id metadata written in
    config/[API]/[SOURCES_METADATA_FILENAME]

    Parameters:
        api_config_path (string): api config path (SOFAR, OMC ...)
        source_id (string): source_id value

    Returns:
        (pandas Dataframe): containing a source_id metadata
    """
    df = lookup_get_sources_id_metadata(api_config_path)
    try:
        return df[source_id]
    except:
        LOGGER.error('Metadata missing for {source_id} in {config_path}'.
                     format(source_id=source_id,
                            config_path=os.path.join(api_config_path,
                                                     SOURCES_METADATA_FILENAME)))


def lookup_get_nc_template(api_config_path, source_id):
    """
    Returns the NetCDF JSON template path to be used for a source_id. The template file should exists under
    config/[api name]/template_[institution_name].json  with institution name in lower case

        Parameters:
            api_config_path (string): api config path (SOFAR, OMC ...)
            source_id (string): source_id value

        Returns:
            path (string): absolute path of NetCDF JSON template

    """
    df = lookup_get_source_id_metadata(api_config_path, source_id)
    try:
        institution_code = df.institution_code
        template_name = 'template_{institution_code}.json'.format(institution_code=institution_code.lower())  # always lower case
    except:
        LOGGER.error('Metadata missing for {source_id} in {config_path}'.format(source_id=source_id,
                                                                                config_path=os.path.join(api_config_path,
                                                                                                         SOURCES_METADATA_FILENAME)))
        return None

    nc_template_path = os.path.join(api_config_path, template_name)
    if not os.path.exists(nc_template_path):
        nc_template_path = resource_filename("ardc_nrt", nc_template_path)

    if not os.path.exists(nc_template_path):
        msg = 'Aborted: {template_name} does not exist. Please create it'.format(template_name=template_name)
        LOGGER.error(msg)
        raise ValueError(msg)

    return nc_template_path


def lookup_get_aodn_variable(api_config_path, institution_variable_name):
    """
    Returns an AODN variable name for a institution variable name

        Parameters:
            api_config_path (string): api config path (SOFAR, OMC ...)
            institution_variable_name (string): value of institution variable

        Returns:
            (str): matching AODN variable name
    """
    lookup_file_path = os.path.join(api_config_path, VARIABLES_LOOKUP_FILENAME)
    if not os.path.exists(lookup_file_path):
        lookup_file_path = resource_filename("ardc_nrt",
                                             lookup_file_path)

    with open(lookup_file_path) as json_obj:
        variables = json.load(json_obj)

    if institution_variable_name in variables.keys():
        if variables[institution_variable_name] != "":
            return variables[institution_variable_name]

    # TODO: improve error
    lookup_file_path = os.path.join(api_config_path, VARIABLES_LOOKUP_FILENAME)
    LOGGER.error('No match up AODN variable for institution variable {variable}. Please modify {lookup_file_path}. '
                 'NetCDF files will be created without this variable'.format(variable=institution_variable_name,
                                                                             lookup_file_path=lookup_file_path))
    return None


def lookup_get_source_id_institution_code(api_config_path, source_id):
    """
    Returns the institution name for a given source_id.
    This is particularly useful for the Sofar API which handles various institutions (vic, uwa...)

    Parameters:
        api_config_path (string): api config path (SOFAR, OMC ...)
        source_id (string): source_id value

        Returns:
            (str): institution name for a given API/source_id
    """
    template_path = os.path.join(api_config_path, SOURCES_METADATA_FILENAME)
    if not os.path.exists(template_path):
        template_path = resource_filename("ardc_nrt",
                                          template_path)

    with open(template_path) as f:
        json_obj = json.load(f)

    if source_id in json_obj.keys():
        return json_obj[source_id]["institution_code"]


def lookup_get_source_id_deployment_start_date(api_config_path, source_id):
    """
    Returns datetime object of the starting date of a source_id as defined by the 'deployment_start' key written in
    SOURCES_METADATA_FILENAME file

        Parameters:
            api_config_path (string): api config path (SOFAR, OMC ...)
            source_id (string): source_id value

        Returns:
            date (pandas.Timestamp): date time of the starting date
    """
    df = lookup_get_source_id_metadata(api_config_path, source_id)

    if hasattr(df, 'deployment_start_date'):
        val = df['deployment_start_date']
    else:
        LOGGER.error('{source_id} is missing a "deployment_start_date" attribute in {metadata_path}: Please amend file'.
                     format(source_id=source_id,
                            metadata_path=os.path.join(api_config_path, SOURCES_METADATA_FILENAME)))
        return

    if pandas.isnull(val):
        LOGGER.error('{source_id} has an empty "deployment_start_date" attribute in {metadata_path}: Please amend file'.
                     format(source_id=source_id,
                            metadata_path=os.path.join(api_config_path, SOURCES_METADATA_FILENAME)))
        return
    #DATE_FORMAT = "%Y-%m-%dT%H:%M:%S.%fZ"
    return pandas.Timestamp(val)


