#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OMC API Documentation available at

Script to download wave data from OMC API.

Data is converted into IMOS compliant NetCDF files
author Laurent Besnard, laurent.besnard@utas.edu.au
"""

import os

import pandas
from ardc_nrt.lib.common.lookup import lookup_get_sources_id_metadata, lookup_get_source_id_metadata
from ardc_nrt.lib.common.pickle_db import pickle_get_latest_processed_date, pickle_file_path
from ardc_nrt.lib.common.processing import process_wave_monthly
from ardc_nrt.lib.common.utils import IMOSLogging
from ardc_nrt.lib.common.utils import args
from ardc_nrt.lib.omc import config
from ardc_nrt.lib.omc.api import api_get_source_id_wave_data_time_range, api_get_source_id_wave_latest_date


def process_wave_source_id(source_id, incoming_path=None):
    LOGGER.info('processing {source_id}'.format(source_id=source_id))

    latest_timestamp_available_source_id = api_get_source_id_wave_latest_date(source_id)
    latest_timestamp_processed_source_id = pickle_get_latest_processed_date(PICKLE_FILE, source_id)

    if latest_timestamp_processed_source_id is None:  # source_id never got downloaded
        source_id_metadata = lookup_get_source_id_metadata(config.conf_dirpath, source_id)
        start_date = source_id_metadata.deployment_start_date

    elif latest_timestamp_processed_source_id < latest_timestamp_available_source_id:
        start_date = latest_timestamp_processed_source_id.replace(day=1, hour=0, minute=0, second=0)  # download from the start of the month

    elif latest_timestamp_processed_source_id == latest_timestamp_available_source_id:
        LOGGER.info('{source_id}: already up to date'.format(source_id=source_id))
        return

    end_date = latest_timestamp_available_source_id  # end_date is the last date available via the API

    data = api_get_source_id_wave_data_time_range(source_id, start_date, end_date)

    if data is None:
        LOGGER.error('Processing {source_id} aborted'.format(source_id=source_id))
        return

    data = data.groupby(pandas.Grouper(key='timestamp', freq='M'))
    # groups to a list of dataframes with list comprehension. One dataframe per month
    dfs = [group for _,group in data]

    # loop over the different months
    for df in dfs:
        df.reset_index(inplace=True)  # for each dataframe, reset the index back to 0
        df.drop(columns='index', inplace=True)

        template_dirpath = config.conf_dirpath
        process_wave_monthly(df, source_id, template_dirpath, OUTPUT_PATH, incoming_path)


if __name__ == "__main__":

    vargs = args()

    # set up logging
    global LOGGER
    LOGGER = IMOSLogging().logging_start(os.path.join(vargs.output_path, 'process.log'))

    # set up saved pickle file to store information of previous runs of the
    # script
    global PICKLE_FILE
    PICKLE_FILE = pickle_file_path(vargs.output_path)

    global OUTPUT_PATH
    OUTPUT_PATH = vargs.output_path

    sources_metadata = lookup_get_sources_id_metadata(config.conf_dirpath)

    for source_id in sources_metadata.keys():
        process_wave_source_id(source_id, incoming_path=vargs.incoming_path)
