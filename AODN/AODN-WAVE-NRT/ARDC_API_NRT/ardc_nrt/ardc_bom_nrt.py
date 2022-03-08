#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
BOM WFS wave data download

Query the BOM WFS for NRT wave data and convert the source_id (WMO code) data into NetCDF ready to be ingested by pipeline

"""
import os

from ardc_nrt.lib.bom import config
from ardc_nrt.lib.bom.wfs import bomWFS
from ardc_nrt.lib.common.lookup import lookup
from ardc_nrt.lib.common.pickle_db import ardcPickle
from ardc_nrt.lib.common.processing import process_wave_dataframe
from ardc_nrt.lib.common.utils import IMOSLogging
from ardc_nrt.lib.common.utils import args


def process_wave_source_id(source_id, incoming_path=None):
    LOGGER.info('processing {source_id}'.format(source_id=source_id))

    ardc_pickle = ardcPickle(OUTPUT_PATH)
    latest_timestamp_processed_source_id = ardc_pickle.get_latest_processed_date(source_id)

    bom = bomWFS()
    df = bom.get_source_id_data(source_id)

    # check new data with already processed one
    if not latest_timestamp_processed_source_id is None:
        df_new_data = df[df["timestamp"] > latest_timestamp_processed_source_id]  # only keep the non processed data
        df_new_data.reset_index(inplace=True)
    else:
        df_new_data = df

    template_dirpath = config.conf_dirpath

    if not df_new_data.empty:
        # create NetCDF filename with true_dates=True (start_date and end_date in NetCDF filename)
        process_wave_dataframe(df_new_data, source_id, template_dirpath, OUTPUT_PATH, incoming_path, true_dates=True)
    else:
        LOGGER.info(f'{source_id} already up to date'.format(source_id=source_id))



if __name__ == "__main__":

    vargs = args()

    # set up logging
    global LOGGER
    LOGGER = IMOSLogging().logging_start(os.path.join(vargs.output_path, 'process.log'))

    # set up output path of the NetCDF files and logging
    global OUTPUT_PATH
    OUTPUT_PATH = vargs.output_path

    # set up saved pickle file to store information of previous runs of the
    # script
    global PICKLE_FILE
    PICKLE_FILE = ardcPickle(OUTPUT_PATH).pickle_file_path()

    api_config = config.conf_dirpath
    ardc_lookup = lookup(api_config)
    sources_id_metadata = ardc_lookup.get_sources_id_metadata()

    for source_id in sources_id_metadata.keys():
        process_wave_source_id(source_id, incoming_path=vargs.incoming_path)
