import json
import logging
import os

import pandas
from pkg_resources import resource_filename

from . import config as config_main


class lookup(object):
    def __init__(self, api_config_path):
        self.api_config_path = api_config_path
        self.sources_metadata_filename = config_main.sources_metadata_filename
        self.variables_lookup_filename = config_main.variables_lookup_filename

        self.logger = logging.getLogger(__name__)

        self.sources_id_metadata_template_path = os.path.join(self.api_config_path, self.sources_metadata_filename)
        if not os.path.exists(self.sources_id_metadata_template_path):
            self.sources_id_metadata_template_path = resource_filename("ardc_nrt",
                                                                       self.sources_id_metadata_template_path)

        self.variables_lookup_file_path = os.path.join(self.api_config_path, self.variables_lookup_filename)
        if not os.path.exists(self.variables_lookup_file_path):
            self.variables_lookup_file_path = resource_filename("ardc_nrt",
                                                                self.variables_lookup_file_path)

        self.sources_id_metadata = self.get_sources_id_metadata()
        self.source_ids = self.sources_id_metadata.keys()

    def get_sources_id_metadata(self):
        """
        Return a pandas dataframe containing all the source_id 's metadata written in
        config/[API]/[SOURCES_METADATA_FILENAME]

            Parameters:

            Returns:
                (pandas Dataframe): containing all source_id's metadata
        """
        df = pandas.read_json(self.sources_id_metadata_template_path)

        return df

    def get_source_id_metadata(self, source_id):
        """
        Return a pandas dataframe containing a source_id metadata written in
        config/[API]/[SOURCES_METADATA_FILENAME]

        Parameters:
            source_id (string): source_id value

        Returns:
            (pandas Dataframe): containing a source_id metadata
        """
        df = self.sources_id_metadata
        try:
            return df[source_id]
        except:
            self.logger.error('Metadata missing for {source_id} in {config_path}'.
                         format(source_id=source_id,
                                config_path=os.path.join(self.api_config_path,
                                                         self.sources_metadata_filename)))

    def get_institution_netcdf_template(self, source_id):
        """
        Returns the NetCDF JSON template path to be used for a source_id. The template file should exists under
        config/[api name]/template_[institution_name].json  with institution name in lower case

            Parameters:

            Returns:
                path (string): absolute path of NetCDF JSON template
        """
        df = self.get_source_id_metadata(source_id)
        try:
            institution_code = df.institution_code
            institution_template_name = 'template_{institution_code}.json'.\
                format(institution_code=institution_code.lower())  # always lower case
        except:
            self.logger.error('Metadata missing for {source_id} in {config_path}'.
                              format(source_id=source_id,
                                     config_path=os.path.join(self.api_config_path,
                                                              self.sources_metadata_filename)))
            return None

        nc_template_path = os.path.join(self.api_config_path, institution_template_name)
        if not os.path.exists(nc_template_path):
            nc_template_path = resource_filename("ardc_nrt", nc_template_path)

        if not os.path.exists(nc_template_path):
            msg = 'Aborted: {institution_template_name} does not exist. Please create it'.\
                format(institution_template_name=institution_template_name)
            self.logger.error(msg)
            raise ValueError(msg)

        self.institution_template_path = nc_template_path
        return nc_template_path

    def get_source_id_institution_code(self, source_id):
        """
        Returns the institution name for a given source_id.
        This is particularly useful for the Sofar API which handles various institutions (vic, uwa...)

            Parameters:

            Returns:
                (str): institution name for a given API/source_id
        """

        with open(self.sources_id_metadata_template_path) as f:
            json_obj = json.load(f)

        if source_id in json_obj.keys():
            return json_obj[source_id]["institution_code"]

    def get_source_id_deployment_start_date(self, source_id):
        """
        Returns datetime object of the starting date of a source_id as defined by the 'deployment_start' key written in
        SOURCES_METADATA_FILENAME file

            Parameters:

            Returns:
                date (pandas.Timestamp): date time of the starting date
        """
        df = self.get_source_id_metadata(source_id)

        if hasattr(df, 'deployment_start_date'):
            val = df['deployment_start_date']
        else:
            self.logger.error(
                '{source_id} is missing a "deployment_start_date" attribute in {metadata_path}: Please amend file'.
                format(source_id=source_id,
                       metadata_path=os.path.join(self.api_config_path, self.sources_metadata_filename)))
            return

        if pandas.isnull(val):
            self.logger.error(
                '{source_id} has an empty "deployment_start_date" attribute in {metadata_path}: Please amend file'.
                format(source_id=source_id,
                       metadata_path=os.path.join(self.api_config_path, self.sources_metadata_filename)))
            return
        return pandas.Timestamp(val)

    def get_matching_aodn_variable(self, institution_variable_name):
        """
        Returns an AODN variable name for a institution variable name

            Parameters:
                institution_variable_name (string): value of institution variable

            Returns:
                (str): matching AODN variable name
        """

        with open(self.variables_lookup_file_path) as json_obj:
            variables = json.load(json_obj)

        if institution_variable_name in variables.keys():
            if variables[institution_variable_name] != "":
                return variables[institution_variable_name]

        return None