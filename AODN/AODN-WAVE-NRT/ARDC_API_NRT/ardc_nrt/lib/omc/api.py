import base64
import datetime
import logging
import os
import sys
from functools import lru_cache

import numpy as np
import pandas
import requests
from ..common import config as config_main
from . import config
from pandas import json_normalize


LOGGER = logging.getLogger(__name__)

DATE_FORMAT = "%Y-%m-%dT%H:%M:%S.%fZ"
SOURCES_METADATA_FILENAME = config_main.sources_metadata_filename
URL_PREFIX = config.url_prefix


@lru_cache(maxsize=32)
def api_get_access_token():
    # TODO: find where to put this secrets.json file and how it will work with packaging the module
    secret_file_path = os.getenv('ARDC_OMC_SECRET_FILE_PATH')

    if secret_file_path is None:
        raise Exception('Please create the ARDC_OMC_SECRET_FILE_PATH environment variable with the path of the secrets.json file')

    if not os.path.exists(secret_file_path):
        raise Exception(
            'The ARDC_OMC_SECRET_FILE_PATH environment variable leads to a non existing file')

    secrets = pandas.read_json(secret_file_path, orient='index')
    client_id = secrets.client_id[0]
    client_secret = secrets.client_secret[0]

    token_url = 'https://auth.sandpit.dukc.net/oauth2/token'

    # get auth token
    authRequest = 'grant_type=client_credentials'
    authClient = client_id + ':' + client_secret
    authHeader = 'Basic ' + base64.b64encode(authClient.encode('utf-8')).decode('utf-8')

    session = requests.session()
    session.trust_env = True
    res = session.post(token_url, data=authRequest, headers={'content-type': 'application/x-www-form-urlencoded', 'Authorization': authHeader})

    if res.status_code != 200:
        print(res)
        sys.exit(res.text)

    authResponse = res.json()
    access_token = authResponse['access_token']

    api_access = {
        'access_token': access_token,
        'session': session
    }

    return api_access


@lru_cache(maxsize=32)
def api_get_sources_info():
    url = URL_PREFIX + 'v1/sources?data_types=wave_observed'

    api_access = api_get_access_token()
    session = api_access['session']
    access_token = api_access['access_token']

    res = session.get(url, headers={'Authorization': 'Bearer ' + access_token, 'User-Agent': 'UTAS'})
    if res.status_code != 200:
        LOGGER.error(res)
        sys.exit(res.text)

    response = res.json()
    sources = response['sources']
    df = json_normalize(sources)

    df.created_time_utc = pandas.to_datetime(df.created_time_utc)

    return df


def api_get_source_info(source_id):
    sources_info = api_get_sources_info()
    val = sources_info.loc[sources_info["id"] == source_id]

    return val.reset_index().drop(columns='index')


def api_get_source_id_query(source_id, query=None):
    url_request = '{url_prefix}v1/data/{source_id}{query}'.\
        format(url_prefix=URL_PREFIX,
               source_id=source_id,
               query=query)

    api_access = api_get_access_token()
    session = api_access['session']
    access_token = api_access['access_token']
    LOGGER.info('API get devices info: {url_request}&Authorization=Bearer%20{token}&User-Agent={user_agent}'.format(
        url_request=url_request,
        token=access_token,
        user_agent='UTAS'))
    res = session.get(url_request, headers={'Authorization': 'Bearer ' + access_token, 'User-Agent': 'UTAS'})

    if res.status_code != 200:
        LOGGER.error(res)
        return

    res_json = res.json()
    df = normalise_json_data(res_json)

    return df


def api_get_source_id_wave_latest_date(source_id):

    df = api_get_source_id_query(source_id, query='/latest?data_types=wave_observed')
    df['time'] = pandas.to_datetime(df['time'])

    df.rename(columns={'time': 'timestamp'}, inplace=True)
    # timestamp is the number of seconds between a particular date and January 1, 1970 at UTC.
    return df.timestamp.max()


def api_get_source_id_wave_data_time_range(source_id, start_date, end_date):
    """
    API call to return source_id data for a given time range

        Parameters:
            source_id (string): source_id value
            start_date (datetime): starting date of data to download (alternatively, it could be a string in ISO ISO8601 format, or -PT1H value)
            end_date (datetime): ending date of data to download (same as above)

        Returns:
            df (pandas dataframe):
    """
    if isinstance(start_date, datetime.datetime):
        start_date = start_date.strftime(DATE_FORMAT)

    if isinstance(end_date, datetime.datetime):
        end_date = end_date.strftime(DATE_FORMAT)

    if isinstance(start_date, float):
        if np.isnan(start_date):
            LOGGER.error('deployment_start_date key for source_id {source_id} is set to None in {config_path}. Please amend'.
                         format(source_id=source_id,
                                config_path=os.path.join(config.conf_dirpath, SOURCES_METADATA_FILENAME)))
            return

    query = '?from_utc={start_date}&to_utc={end_date}&data_types=wave_observed'.\
        format(url_prefix=URL_PREFIX,
               source_id=source_id,
               start_date=start_date,
               end_date=end_date)

    df = api_get_source_id_query(source_id, query=query)

    df['time'] = pandas.to_datetime(df['time'])
    df.rename(columns={'time': 'timestamp'}, inplace=True)

    # append latitude and longitude to dataframe
    api_metadata = api_get_source_info(source_id)
    df = df.assign(latitude=np.repeat(api_metadata.coordinates[0][1], df.shape[0]))
    df = df.assign(longitude=np.repeat(api_metadata.coordinates[0][0], df.shape[0]))

    return df


def normalise_json_data(json_input_object):
    df = pandas.DataFrame()
    for i, var in enumerate(json_input_object[0]['variables'].keys()):
        df.insert(i, var, json_input_object[0]['variables'][var]["data"])

    df.set_index('time')

    return df