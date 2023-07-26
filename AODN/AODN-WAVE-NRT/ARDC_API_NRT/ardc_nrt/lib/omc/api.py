import base64
import datetime
import logging
import os
from functools import lru_cache
from requests.adapters import HTTPAdapter, Retry

import numpy as np
import pandas
import requests
from ..common import config as config_main
from . import config
from pandas import json_normalize


class omcApi(object):
    def __init__(self, source_id=None):
        self.source_id = source_id

        self.api_access = self.get_access_token()
        self.session = self.api_access['session']
        self.access_token = self.api_access['access_token']

        self.logger = logging.getLogger(__name__)

        self.date_format = "%Y-%m-%dT%H:%M:%S.%fZ"
        self.source_metadata_filename = config_main.sources_metadata_filename
        self.url_prefix = config.url_prefix

    @lru_cache(maxsize=32)
    def get_access_token(self):
        secret_file_path = os.getenv('ARDC_OMC_SECRET_FILE_PATH')

        if secret_file_path is None:
            raise Exception('Please create the ARDC_OMC_SECRET_FILE_PATH environment variable with the path of the secrets.json file')

        if not os.path.exists(secret_file_path):
            raise Exception(
                'The ARDC_OMC_SECRET_FILE_PATH environment variable leads to a non existing file')

        secrets = pandas.read_json(secret_file_path, orient='index')
        client_id = secrets.client_id[0]
        client_secret = secrets.client_secret[0]

        token_url = 'https://auth.omcinternational.com/oauth2/token'

        # get auth token
        authRequest = 'grant_type=client_credentials'
        authClient = client_id + ':' + client_secret
        authHeader = 'Basic ' + base64.b64encode(authClient.encode('utf-8')).decode('utf-8')

        session = requests.session()
        session.trust_env = True
        res = session.post(token_url, data=authRequest, headers={'content-type': 'application/x-www-form-urlencoded',
                                                                 'Authorization': authHeader})

        if res.status_code != 200:
            self.logger.error(res)
            return

        authResponse = res.json()
        access_token = authResponse['access_token']

        api_access = {
            'access_token': access_token,
            'session': session
        }

        return api_access

    @lru_cache(maxsize=32)
    def get_sources_info(self):
        url = self.url_prefix + 'v1/sources?data_types=wave_observed'

        res = self.session.get(url, headers={'Authorization': 'Bearer ' + self.access_token, 'User-Agent': 'UTAS'})
        if res.status_code != 200:
            self.logger.error(res)
            return

        response = res.json()
        sources = response['sources']
        df = json_normalize(sources)

        df.created_time_utc = pandas.to_datetime(df.created_time_utc)

        return df

    def get_source_info(self):
        sources_info = self.get_sources_info()
        val = sources_info.loc[sources_info["id"] == self.source_id]

        return val.reset_index().drop(columns='index')

    def get_source_id_wave_latest_date(self):
        df = self.get_source_id_query(query='/latest?data_types=wave_observed')
        df['time'] = pandas.to_datetime(df['time'])

        df.rename(columns={'time': 'timestamp'}, inplace=True)
        # timestamp is the number of seconds between a particular date and January 1, 1970 at UTC.
        return df.timestamp.max()

    def get_source_id_query(self, query=None):
        url_request = '{url_prefix}v1/data/{source_id}{query}'.\
            format(url_prefix=self.url_prefix,
                   source_id=self.source_id,
                   query=query)

        self.logger.info('API call: {url_request}&Authorization=Bearer%20{token}&User-Agent={user_agent}'.
            format(
            url_request=url_request,
            token=self.access_token,
            user_agent='UTAS'))
        # make all HTTPs requests from the same session retry for a total of 5 times,
        # sleeping between retries with an increasing backoff of 0s, 2s, 4s, 8s, 16
        # see https://stackoverflow.com/questions/23267409/how-to-implement-retry-mechanism-into-python-requests-library
        retries = Retry(total=5, backoff_factor=1, status_forcelist=[502, 503, 504])
        self.session.mount('https://', HTTPAdapter(max_retries=retries))
        res = self.session.get(url_request, headers={'Authorization': 'Bearer ' + self.access_token, 'User-Agent': 'UTAS'})
        if res.status_code != 200:
            if res.status_code == 504:
                self.logger.error('API Gateway timeout error 504. {error}'.format(error=res))
            else:
                msg = res.reason
                self.logger.error(msg)
            return

        res_json = res.json()
        df = normalise_json_data(res_json)

        return df

    def get_source_id_wave_data_time_range(self, start_date, end_date):
        """
        API call to return source_id data for a given time range

            Parameters:
                start_date (datetime): starting date of data to download (alternatively, it could be a string in ISO ISO8601 format, or -PT1H value)
                end_date (datetime): ending date of data to download (same as above)

            Returns:
                df (pandas dataframe):
        """
        if isinstance(start_date, datetime.datetime):
            if isinstance(start_date,type(pandas.NaT)):
                self.logger.error('{source_id}: deployment_start_date key is set to None in {config_path}. Please amend'.
                                  format(source_id=self.source_id,
                                         config_path=os.path.join(config.conf_dirpath, self.source_metadata_filename)))
                return

            start_date = start_date.strftime(self.date_format)

        if isinstance(end_date, datetime.datetime):
            end_date = end_date.strftime(self.date_format)

  #      if isinstance(start_date, float):
  #          if np.isnan(start_date):
  #              self.logger.error('{source_id}: deployment_start_date key is set to None in {config_path}. Please amend'.
  #                                format(source_id=self.source_id,
  #                                       config_path=os.path.join(config.conf_dirpath, self.source_metadata_filename)))
  #              return

        query = '?from_utc={start_date}&to_utc={end_date}&data_types=wave_observed'.\
            format(url_prefix=self.url_prefix,
                   source_id=self.source_id,
                   start_date=start_date,
                   end_date=end_date)

        df = self.get_source_id_query(query=query)

        df['time'] = pandas.to_datetime(df['time'])
        df.rename(columns={'time': 'timestamp'}, inplace=True)

        # append latitude and longitude to dataframe
        api_metadata = self.get_source_info()
        df = df.assign(latitude=np.repeat(api_metadata.coordinates[0][1], df.shape[0]))
        df = df.assign(longitude=np.repeat(api_metadata.coordinates[0][0], df.shape[0]))

        return df


def normalise_json_data(json_input_object):
    df = pandas.DataFrame()
    for i, var in enumerate(json_input_object[0]['variables'].keys()):
        df.insert(i, var, json_input_object[0]['variables'][var]["data"])

    df.set_index('time')

    return df
