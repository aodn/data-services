#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
SOFAR API Documentation available at https://docs.sofarocean.com/

Script to download wave data from SOFAR API.

Data is converted into IMOS compliant NetCDF files
author Laurent Besnard, laurent.besnard@utas.edu.au
"""

import datetime
import os

import pandas
from ardc_nrt.lib.common.lookup import lookup_get_sources_id_metadata, lookup_get_source_id_deployment_start_date
from ardc_nrt.lib.common.pickle_db import pickle_get_latest_processed_date, pickle_file_path
from ardc_nrt.lib.common.processing import process_wave_monthly, get_timestamp_start_end_to_download
from ardc_nrt.lib.common.utils import IMOSLogging
from ardc_nrt.lib.common.utils import args
from ardc_nrt.lib.sofar import config
from ardc_nrt.lib.sofar.api import api_get_source_id_latest_timestamp, api_get_source_id_wave_data_time_range, \
    api_get_source_id_latest_data
from dateutil.relativedelta import relativedelta
from dateutil.rrule import rrule, MONTHLY


def process_wave_source_id(source_id, incoming_path=None):
    """
    Core function which process all new data available for a spotter_id

        Parameters:
            source_id (string): spotter_id value

        Returns:
    """
    LOGGER.info('processing {source_id}'.format(source_id=source_id))

    latest_timestamp_available_source_id = api_get_source_id_latest_timestamp(source_id)
    latest_timestamp_processed_source_id = pickle_get_latest_processed_date(PICKLE_FILE, source_id)

    timestamp_start_end = get_timestamp_start_end_to_download(config.conf_dirpath, source_id,
                                                                         latest_timestamp_available_source_id,
                                                                         latest_timestamp_processed_source_id)
    if not timestamp_start_end:  #  already up to date
        return

    timestamp_start, timestamp_end = timestamp_start_end

    # api call to download one month at a time
    start_date = timestamp_start.replace(tzinfo=datetime.timezone.utc)
    end_date = timestamp_end.to_pydatetime().replace(tzinfo=datetime.timezone.utc)
    months_to_download = [dt for dt in rrule(MONTHLY, dtstart=start_date, until=end_date + relativedelta(months=1))][0:-1]

    for month in months_to_download:
        data = api_get_source_id_wave_data_time_range(source_id, month, month + relativedelta(months=1))

        if data is None:
            LOGGER.error('Processing {source_id} aborted'.format(source_id=source_id))
            return

        # if we're processing the latest month of data available, we're
        # appending to the data pandas dataframe data from the "latest-data" SOFAR API
        # call which is not available in the historical API call.
        if month == months_to_download[-1]:
            # try:
            data_latest = api_get_source_id_latest_data(source_id)
            if data_latest is not None:
                data = pandas.concat([data, data_latest])

        if data is not None:
            template_dirpath = config.conf_dirpath
            process_wave_monthly(data, source_id, template_dirpath, OUTPUT_PATH, incoming_path)


if __name__ == "__main__":

    vargs = args()

    # set up logging
    global LOGGER
    LOGGER = IMOSLogging().logging_start(os.path.join(vargs.output_path, 'process.log'))

    # set up saved pickle file to store information of previous runs of the
    # script
    global PICKLE_FILE
    PICKLE_FILE = pickle_file_path(vargs.output_path)

    # set up output path of the NetCDF files and logging
    global OUTPUT_PATH
    OUTPUT_PATH = vargs.output_path

    sources_id_metadata = lookup_get_sources_id_metadata(config.conf_dirpath)

    for source_id in sources_id_metadata.keys():
        process_wave_source_id(source_id, incoming_path=vargs.incoming_path)
