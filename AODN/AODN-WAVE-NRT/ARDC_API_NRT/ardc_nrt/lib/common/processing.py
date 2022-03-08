import logging
import os
import shutil
import traceback

import pandas

from .lookup import lookup
from .netcdf import wave
from .pickle_db import ardcPickle

LOGGER = logging.getLogger(__name__)


def process_wave_dataframe(df, source_id, template_dirpath, output_dir_path, incoming_path=None, true_dates=False):
    """"
    process a pandas dataframe containing data for one source_id :
        - create an IMOS compliant NetCDF file
        - save the last successfully processed date into a pickle file
        - move to an AODN incoming directory if set

        Parameters:
            df (pandas dataFrame): containing wave data
            source_id (int/str): source_id (spotter_id, wmo_id ...) to process
            template_dirpath (str): path of the config template
            incoming_path (string): path of the AODN pipeline incoming directory for ingestion
            true_dates (boolean): default (False) -> NetCDF filename date is monthly ..._{date_start}_monthly_FV00_END
                                             True -> filename is ..._{date_start}_FV00_END-{date_end}.nc
    """
    error = 0
    try:
        ardc_netcdf = wave(template_dirpath, source_id, df, output_dir_path)

        netcdf_file_path = ardc_netcdf.convert_wave_data_to_netcdf(true_dates)
        LOGGER.info('{nc_path} created successfully'.format(nc_path=netcdf_file_path))

    except Exception as err:
        error = 1
        LOGGER.error(str(err))
        LOGGER.error(traceback.print_exc())

    if error == 0:
        ardc_pickle = ardcPickle(output_dir_path)
        ardc_pickle.save_latest_download_success(source_id, netcdf_file_path)

        if incoming_path:
            if os.path.exists(incoming_path):
                shutil.move(netcdf_file_path, incoming_path)
            else:
                LOGGER.error(
                    '{incoming_path} is not accessible. {netcdf_file_path} will have to be moved manually'.float(
                        incoming_path=incoming_path,
                        netcdf_file_path=netcdf_file_path
                    ))


def get_timestamp_start_end_to_download(conf_dirpath, source_id, latest_timestamp_available_source_id,
                                        latest_timestamp_processed_source_id):
    """

    """
    ardc_lookup = lookup(conf_dirpath)
    #ardc_lookup.source_id = source_id

    if latest_timestamp_processed_source_id is None:  # source_id never got downloaded
        timestamp_start = ardc_lookup.get_source_id_deployment_start_date(source_id)
        if not timestamp_start:
            return
        latest_timestamp_processed_source_id = timestamp_start

    if latest_timestamp_available_source_id is None:  # api not capable of returning latest date available. assuming now()
        latest_timestamp_available_source_id = pandas.Timestamp.now()
        timestamp_end = latest_timestamp_available_source_id

    elif latest_timestamp_processed_source_id > latest_timestamp_available_source_id:
        LOGGER.error('{source_id}: Latest date available {latest_date} is less than starting date to download {starting_date}. '
                     'Probably due to a wrong value in {conf_dirpath}/sources_id.metadata.json'.
                     format(source_id=source_id,
                            latest_date=latest_timestamp_available_source_id,
                            starting_date=latest_timestamp_processed_source_id,
                            conf_dirpath=conf_dirpath))
        return

    elif latest_timestamp_processed_source_id < latest_timestamp_available_source_id:
        timestamp_start = latest_timestamp_processed_source_id.replace(day=1, hour=0, minute=0,
                                                                  second=0)  # download from the start of the month

    elif latest_timestamp_processed_source_id == latest_timestamp_available_source_id:
        LOGGER.info('{source_id}: latest date available {latest_date} already downloaded'.format(source_id=source_id,
                                                                                                 latest_date=latest_timestamp_available_source_id))
        return

    timestamp_end = latest_timestamp_available_source_id

    return timestamp_start, timestamp_end