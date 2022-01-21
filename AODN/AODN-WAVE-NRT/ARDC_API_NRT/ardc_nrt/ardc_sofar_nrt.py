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
import shutil
import traceback

import pandas
from ardc_nrt.lib.common.lookup import lookup_get_sources_id_metadata, lookup_get_source_id_deployment_start_date
from ardc_nrt.lib.common.netcdf import convert_wave_data_to_netcdf, merge_source_institution_json_template
from ardc_nrt.lib.common.pickle_db import pickle_get_latest_processed_date, pickle_save_latest_download_success
from ardc_nrt.lib.common.utils import args
from ardc_nrt.lib.sofar import config
from ardc_nrt.lib.sofar.api import api_get_source_id_latest_timestamp, api_get_source_id_wave_data_time_range, \
    api_get_source_id_latest_data
from dateutil.relativedelta import relativedelta
from dateutil.rrule import rrule, MONTHLY
from ardc_nrt.lib.common.utils import IMOSLogging


def process_wave_source_id(source_id, incoming_path=None):
    """
    Core function which process all new data available for a spotter_id

        Parameters:
            source_id (string): spotter_id value

        Returns:
    """
    latest_date_available_source_id = api_get_source_id_latest_timestamp(source_id)
    latest_date_processed_source_id = pickle_get_latest_processed_date(PICKLE_FILE, source_id)

    if latest_date_available_source_id is None:
        latest_date_available_source_id = datetime.datetime.now()

    if latest_date_processed_source_id is None:
        # TODO rewrite this function and the logic as we may have to download
        # many deployments per spotter
        start_date = lookup_get_source_id_deployment_start_date(config.conf_dirpath, source_id)

    elif latest_date_processed_source_id < latest_date_available_source_id:
        start_date = latest_date_processed_source_id.replace(day=1, hour=0, minute=0, second=0)  # download from the start of the month

    elif latest_date_processed_source_id == latest_date_available_source_id:
        LOGGER.info('{source_id}: already up to date'.format(source_id=source_id))
        return

    end_date = latest_date_available_source_id

    # TODO: fix this uggly thing re timezone. why did i write  datetime.datetime.now() above. check everything
    start_date = start_date.replace(tzinfo=datetime.timezone.utc)
    end_date = end_date.to_pydatetime()

    months_to_download = [dt for dt in rrule(MONTHLY, dtstart=start_date, until=end_date + relativedelta(months=1))][0:-1]

    for month in months_to_download:
        error = 0
        data = api_get_source_id_wave_data_time_range(source_id, month, month + relativedelta(months=1))

        # if we're processing the latest month of data available, we're
        # appending to the data pandas dataframe data from the "latest-data" SOFAR API
        # call which is not available in the historical API call.
        if month == months_to_download[-1]:
            # try:
            data_latest = api_get_source_id_latest_data(source_id)
            if data_latest is not None:
                data = pandas.concat([data, data_latest])

        if data is not None:
            try:

                template_dirpath = config.conf_dirpath
                netcdf_template_path = merge_source_institution_json_template(template_dirpath, source_id)
                nc_path = convert_wave_data_to_netcdf(template_dirpath, netcdf_template_path, data, OUTPUT_PATH)
                LOGGER.info('{nc_path} created successfully'.format(nc_path=nc_path))

                # TODO: create the push to incoming directory part
            except Exception as err:
                error = 1
                LOGGER.error(str(err))
                LOGGER.error(traceback.print_exc())

            if error == 0:
                pickle_save_latest_download_success(PICKLE_FILE, source_id, nc_path)

                if incoming_path:
                    shutil.move(nc_path, incoming_path)


if __name__ == "__main__":

    vargs = args()

    # set up logging
    global LOGGER
    LOGGER = IMOSLogging().logging_start(os.path.join(vargs.output_path, 'process.log'))

    # set up saved pickle file to store information of previous runs of the
    # script
    global PICKLE_FILE
    PICKLE_FILE = os.path.join(vargs.output_path, 'pickle.db')

    # set up output path of the NetCDF files and logging
    global OUTPUT_PATH
    OUTPUT_PATH = vargs.output_path

    sources_id_metadata = lookup_get_sources_id_metadata(config.conf_dirpath)

    for source_id in sources_id_metadata.keys():
        process_wave_source_id(source_id, incoming_path=vargs.incoming_path)
