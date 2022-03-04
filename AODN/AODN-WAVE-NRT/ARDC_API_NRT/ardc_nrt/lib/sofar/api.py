import datetime
import json
import logging
import os

import pandas
from ..common import config as config_main
from ..common.lookup import lookup
from ..sofar import config
from requests import get


class apiSofar():
    def __init__(self):
        self.url_prefix = config.url_prefix
        self.sources_metadata_filename = config_main.sources_metadata_filename
        self.date_format = "%Y-%m-%dT%H:%M:%S.%fZ"
        self.logger = logging.getLogger(__name__)

        self.tokens = self.lookup_get_tokens()
        self.api_config = config.conf_dirpath

    def lookup_get_tokens(self):
        """
        Returns of list of tokens for the SOFAR API access from ARDC_SOFAR_SECRET_FILE_PATH

            Parameters:

            Returns: json object containing various SOFAR tokens
        """
        # TODO: find where to put this secrets.json file and how it will work with packaging the module
        secret_file_path = os.getenv('ARDC_SOFAR_SECRET_FILE_PATH')

        if secret_file_path is None:
            raise Exception('Please create the ARDC_SOFAR_SECRET_FILE_PATH environment variable with the path of the secrets.json file')
            return

        if not os.path.exists(secret_file_path):
            raise Exception(
                'The ARDC_SOFAR_SECRET_FILE_PATH environment variable leads to a non existing file')

        with open(secret_file_path) as f:
            json_obj = json.load(f)

        return json_obj


    def lookup_get_source_id_token(self, source_id):
        """
        Find the corresponding token of a source_id

            Parameters:

            Returns: token (string): value matching the source_id
        """
        ardc_lookup = lookup(self.api_config)
        ardc_lookup.source_id = source_id
        sources_id_metadata = ardc_lookup.get_source_id_institution_code()

        institution_code = ardc_lookup.get_source_id_institution_code()

        if institution_code in self.tokens.keys():
            token = self.tokens[institution_code]
            return token


    def get_source_id_latest_timestamp(self, source_id):
        """
        API call to get the latest date of data available for a given source_id

            Parameters:
                source_id (string): source_id value

            Returns:
                (pandas timestamp): latest date available
        """
        url_request = '{url_prefix}/latest-data?spotterId={source_id}'.format(url_prefix=self.url_prefix,
                                                                               source_id=source_id)

        token = self.lookup_get_source_id_token(source_id)
        self.logger.info('API get device latest date available: {url_request}&token={token}'.format(url_request=url_request,
                                                                                               token=token))

        headers = {'token': token}
        res = get(url_request, headers=headers)
        res_json = res.json()

        try:
            latest_date_str = res_json['data']['waves'][-1]['timestamp']
        except:
            self.logger.error('API not returning latest date for {source_id}'.format(source_id=source_id))
            return None

        latest_date = pandas.Timestamp(latest_date_str)

        return latest_date


    def get_source_id_wave_data_time_range(self, source_id, start_date, end_date):
        """
        API call to return source_id data for a given time range (historical only)

            Parameters:
                source_id (string): spotter_id value
                start_date (datetime): starting datetime (UTC) of data to download
                end_date (datetime): ending datetime (UTC) of data to download

            Returns:
                df (pandas dataframe):
        """
        url_request = ("{url_prefix}/wave-data?spotterId={source_id}&"\
                       "startDate={start_date}&"\
                       "endDate={end_date}").format(url_prefix=self.url_prefix,
                                                    source_id=source_id,
                                                    start_date=start_date.strftime(self.date_format),
                                                    end_date=end_date.strftime(self.date_format))

        token = self.lookup_get_source_id_token(source_id)
        headers = {'token': token}
        res = get(url_request, headers=headers)
        self.logger.info('API get source_id data: {url_request}&token={token}'.format(url_request=url_request,
                                                                               token=token))
        res_json = res.json()

        df = pandas.json_normalize(res_json['data']['waves'])
        if len(df) == 0:
            self.logger.warning('{source_id}: no data between {start_date} -> {end_date}'.format(source_id=source_id,
                                                                                             start_date=start_date.strftime(self.date_format),
                                                                                             end_date=end_date.strftime(self.date_format)))
            return None

        self.logger.info('{source_id}: data downloaded between {start_date} -> {end_date}'.format(source_id=source_id,
                                                                                              start_date=start_date.strftime(self.date_format),
                                                                                              end_date=end_date.strftime(self.date_format)))
        df['timestamp'] = pandas.to_datetime(df['timestamp'])
        return df


    def get_devices_info(self, token):
        """
        API call to retrieve source_id information

            Parameters:

            Returns:
                df (pandas dataframe): devices information
        """
        url_request = '{url_prefix}/devices?'.format(url_prefix=self.url_prefix)
        self.logger.info('API get devices info: {url_request}&token={token}'.format(url_request=url_request,
                                                                               token=token))

        headers = {'token': token}
        res = get(url_request, headers=headers)
        res_json = res.json()

        df = pandas.json_normalize(res_json['data']['devices'])

        return df


    def get_source_id_latest_data(self, source_id):
        """
        Returns the latest data available for a given source_id.
        The latest-data API call is different from the historical API call

            Parameters:
                source_id (string): source_id value

            Returns:
                df (pandas dataframe): latest data available
        """
        url_request = '{url_prefix}/latest-data?spotterId={source_id}'.format(url_prefix=self.url_prefix,
                                                                               source_id=source_id)

        token = self.lookup_get_source_id_token(source_id)
        headers = {'token': token}
        res = get(url_request, headers=headers)
        res_json = res.json()

        df = pandas.json_normalize(res_json['data']['waves'])
        try:
            df['timestamp'] = pandas.to_datetime(df['timestamp'])
        except:
            self.logger.error('{source_id}: No valid data available'.format(source_id=source_id))
            return None

        return df
