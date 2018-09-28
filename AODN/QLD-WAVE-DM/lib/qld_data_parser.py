import datetime
import json
from urllib2 import Request, urlopen, URLError

import pandas as pd
from pandas.io.json import json_normalize
from retrying import retry

from .common import *

logger = logging.getLogger(__name__)


def retry_if_urlerror_error(exception):
    """Return True if we should retry (in this case when it's an URLError), False otherwise"""
    return isinstance(exception, URLError)


@retry(retry_on_exception=retry_if_urlerror_error, stop_max_attempt_number=10)
def retrieve_json_data(resource_id):
    """
    downloads the data in json format for a resource_id. Perform some data cleaning and returns a panda dataframe
    :param resource_id:
    :return: panda dataframe
    """
    # warning by default, only 100 rows. Need to specify the total number of records in the url request
    # Number of records stored in the field 'total'

    base_data_url = '{base_url_data}{resource_id}'.format(base_url_data=BASE_URL_DATA,
    resource_id = resource_id)

    logger.info('Parsing {url}'.format(url=base_data_url))


    try:
        request = Request(base_data_url)
        response = urlopen(request)
    except:
        logger.error('{url} not reachable. Retry'.format(url=base_data_url))
        raise URLError

    # request size of dataset first
    r_out = response.read()
    r_data = json.loads(r_out)
    nb_records = r_data['result']['total']

    # Specify limit to request full dataset
    data_url = '{base_url_data}{resource_id}&limit={limit}'.format(base_url_data=BASE_URL_DATA,
                                                                   resource_id=resource_id,
                                                                   limit=nb_records)
    try:
        request = Request(data_url)
        response = urlopen(request)
    except:
        logger.error('{url} not reachable. Retry'.format(url=data_url))
        raise URLError

    res_out = response.read()
    json_data = json.loads(res_out)
    df = json_normalize(json_data['result']['records']
                        )
    try:
        df = find_datetime_var(json_data, df)
    except ValueError:
        return

    return data_cleaning(df)


def find_datetime_var(json_data, df):
    """
    Various date labels. Looking for 'timestamp' in field definition of json and rename column to datetime in df
    :param json_data:
    :param df:
    :return: df
    """
    for field in json_data['result']['fields']:
        if field['type'] == 'timestamp':
            time_var_name = field['id']
            break

    if 'time_var_name' not in vars():
        logger.error('Unknown Date column name')
        raise ValueError
    else:
        df.rename(columns={time_var_name: "datetime"}, inplace=True)

    return df


def data_cleaning(df):
    """
    order needs to be respected
    :param df:
    :return:
    """
    df = _data_cleaning_convert_to_datetime(df)
    df = _data_convert_to_utc(df)
    df = _data_cleaning_set_time_index(df)
    df = _data_cleaning_drop_col(df)
    df = _data_cleaning_drop_single_unique_values_var(df)
    df = _data_cleaning_fillvalue(df)
    df = _data_cleaning_replace_val_with_fillvalue(df)
    df = _data_cleaning_drop_similar_values(df)  # decided not to do any "complicated" QC
    return df


def _data_cleaning_convert_to_datetime(df):
    # handle different time format
    try:
        format = '%Y-%m-%dT%H:%M:%S'
        datetime.datetime.strptime(df['datetime'][0], format)
    except Exception:
        try:
            format = '%Y/%m/%d %H:%M:%S'
            datetime.datetime.strptime(df['datetime'][0], format)
        except Exception:
            logger.error('Unknown datetime format from json data')
            return

    logger.info('Datetime format from json data parsed with format: {format}'.format(format=format))
    df['datetime'] = pd.to_datetime(df['datetime'], format=format)
    return df


def _data_convert_to_utc(df):
    """
    Queensland data is written in local time. substract 10 hours. No day light saving
    :param df:
    :return: df
    """
    df.datetime = df.datetime - datetime.timedelta(hours=10)
    return df


def _data_cleaning_drop_col(df):
    """
    drop column _id
    :param df:
    :return: df
    """
    if '_id' in df.columns:
        df.drop('_id', axis=1, inplace=True)
    return df


def _data_cleaning_set_time_index(df):
    """
    set datetime column as a dataframe index. Remove NaN values and sort df according to datetime
    :param df:
    :return: df
    """
    df.dropna(subset=['datetime'], inplace=True)  # remove all rows where datetime is NaN. Many rows are affected
    df.set_index('datetime', inplace=True)
    df.sort_index(axis=0, inplace=True)  # the json output is not sorted by default
    return df


def _data_cleaning_drop_single_unique_values_var(df):
    """
    Some variables contain only one value for the full timeseries. We dropping those columns
    :param df:
    :return: df
    """
    nunique = df.apply(pd.Series.nunique)
    cols_to_drop = nunique[nunique == 1].index
    for col_to_drop in cols_to_drop:
        logger.warning('Dropping parameter {parameter} from dataframe as no valid value'.format(parameter=col_to_drop))
    df.drop(cols_to_drop, axis=1, inplace=True)
    return df


def _data_cleaning_fillvalue(df):
    """
    Replace various fillvalues with proper FILLVALUE
    :param df:
    :return: df
    """
    # replace dataframe various fillvalues with fillvalue used in NetCDF
    df.replace('', FILLVALUE, inplace=True)
    df.replace(-99.9, FILLVALUE, inplace=True)
    df.replace(-9999, FILLVALUE, inplace=True)
    return df


def _data_cleaning_replace_val_with_fillvalue(df):
    """
    may SST values are set to 0. We replace those with FILLVALUE
    :param df:
    :return: df
    """
    if 'SST' in df.columns:
        df['SST'].replace(0, FILLVALUE, inplace=True)  # many sst values set to 0 instead of fillvalue
    return df


def _data_cleaning_drop_similar_values(df):
    """
    masking values which are consecutively identical. Needs to be performed after a sort on datetime
    :param df:
    :return: df
    """
    if 'SST' in df.columns:
        df = df.mask((df.shift(1) == df) &
                     (df.shift(2) == df) &
                     (df.shift(3) == df) &
                     (df.shift(4) == df))
    return df
