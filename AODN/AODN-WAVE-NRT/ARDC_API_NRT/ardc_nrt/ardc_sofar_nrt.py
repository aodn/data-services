#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
SOFAR API Documentation available at https://docs.sofarocean.com/

Script to download wave data from SOFAR API.

Data is converted into IMOS compliant NetCDF files
author Laurent Besnard, laurent.besnard@utas.edu.au
"""

import datetime
import logging
import os

from ardc_nrt.lib.common.lookup import lookup
from ardc_nrt.lib.common.pickle_db import ardcPickle
from ardc_nrt.lib.common.processing import process_wave_dataframe, get_timestamp_start_end_to_download
from ardc_nrt.lib.common.utils import IMOSLogging, args
from ardc_nrt.lib.sofar import config
from ardc_nrt.lib.sofar.api import sofarApi
from dateutil.relativedelta import relativedelta
from dateutil.rrule import rrule, MONTHLY

limit_outlier = 0.02  # value (in degree) where a data point is considered outlier
limit_error = 0.1  # value (in degree) where a data point is considered erroneous


def process_wave_source_id(source_id, incoming_path=None):
    """
    Core function which process all new data available for a source_id

        Parameters:
            source_id (string): spotter_id value
            incoming_path (string): AODN pipeline incoming path

        Returns:
    """
    sources_id_metadata = ardc_lookup.get_sources_id_metadata()
    site_name = sources_id_metadata[source_id]['site_name']
    LOGGER.info(f'processing source_id: {source_id}')
    LOGGER.info(f'site_name: {site_name}')

    api_sofar = sofarApi()

    # checking for missing tokens:
    if api_sofar.lookup_get_source_id_token(source_id) is not None:
        pass
    else:
        message_add_error(source_id, "API error: missing token. Please note that institution names are case sensitive.")
        return

    # warning for missing deployment date (removed buoys are kept in the metadata, but without deployment date)
    if sources_id_metadata[source_id][
        'deployment_start_date'] != "" and ardc_lookup.get_source_id_deployment_start_date(source_id) is not None:
        pass
    else:
        message_add_warning(source_id, "Deployment start date missing. Download of data skipped.")
        return

    latest_timestamp_available_source_id = api_sofar.get_source_id_latest_timestamp(source_id)

    ardc_pickle = ardcPickle(OUTPUT_PATH)
    latest_timestamp_processed_source_id = ardc_pickle.get_latest_processed_date(source_id)

    timestamp_start_end = get_timestamp_start_end_to_download(config.conf_dirpath, source_id,
                                                              latest_timestamp_available_source_id,
                                                              latest_timestamp_processed_source_id)
    if not timestamp_start_end:  # data downloaded already up to date
        return

    timestamp_start, timestamp_end = timestamp_start_end

    # api call to download one month at a time
    start_date = timestamp_start.replace(tzinfo=datetime.timezone.utc)
    end_date = timestamp_end.to_pydatetime().replace(tzinfo=datetime.timezone.utc)
    months_to_download = [dt for dt in rrule(MONTHLY, dtstart=start_date, until=end_date + relativedelta(months=1))][
                         0:-1]

    #  check the coordinates of the api vs buoy metadata. Will be compared to the coordinates in monthly API data
    data_full = api_sofar.get_source_id_wave_data_time_range(source_id, start_date, end_date)
    lat_meta = sources_id_metadata[source_id]['latitude_nominal']
    lon_meta = sources_id_metadata[source_id]['longitude_nominal']
    lat_api_last = data_full.iloc[-1]['latitude']
    lon_api_last = data_full.iloc[-1]['longitude']
    diff_lat_last_api = abs(lat_api_last - lat_meta)
    diff_lon_last_api = abs(lon_api_last - lon_meta)

    for month in months_to_download:

        data = api_sofar.get_source_id_wave_data_time_range(source_id, month, month + relativedelta(months=1))

        if data is None:
            message_add_warning(source_id, f"No data available BETWEEN {month} AND {month + relativedelta(months=1)}.")
            continue

        if data is not None:
            # Comparing the coordinates of last data in API to metadata and finding the outliers (2-10km) and
            #   errors (>10km)
            # It logs the first and last outliers and errors and check how long for, and issues error or warning.

            lat_month_last = data.iloc[-1]['latitude']
            lon_month_last = data.iloc[-1]['longitude']
            diff_lat_last = abs(lat_month_last - lat_meta)
            diff_lon_last = abs(lon_month_last - lon_meta)

            outliers_coordinates = data[
                ((abs(data['latitude'] - lat_meta) > limit_outlier) & (
                        abs(data['latitude'] - lat_meta) < limit_error)) |
                ((abs(data['longitude'] - lon_meta) > limit_outlier) & (
                        abs(data['longitude'] - lon_meta) < limit_error))]
            error_coordinates = data[
                (abs(data['latitude'] - lat_meta) >= limit_error) | (abs(data['longitude'] - lon_meta) >= limit_error)]

            if outliers_coordinates.empty:
                pass
            else:
                first_outlier = outliers_coordinates.iloc[0]['timestamp'].strftime("%Y-%m-%d %H:%M:%S")
                last_outlier = outliers_coordinates.iloc[-1]['timestamp'].strftime("%Y-%m-%d %H:%M:%S")

                # if there is data that has not been downloaded before the coordinates issue, it will get it
                partial_data_outlier = data[data['timestamp'] < outliers_coordinates.iloc[0]['timestamp']]

            if error_coordinates.empty:
                pass
            else:
                first_error_coordinates = error_coordinates.iloc[0]['timestamp'].strftime("%Y-%m-%d %H:%M:%S")
                last_error_coordinates = error_coordinates.iloc[-1]['timestamp'].strftime("%Y-%m-%d %H:%M:%S")
                time_error = (datetime.datetime.strptime(last_error_coordinates, "%Y-%m-%d %H:%M:%S") -
                              datetime.datetime.strptime(first_error_coordinates, "%Y-%m-%d %H:%M:%S"))
                error_month = month
                error_month.strftime("%Y-%m-%d %H:%M:%S")

                # if there is data that has not been downloaded before the coordinates issue, it will get it
                partial_data_error = data[data['timestamp'] < error_coordinates.iloc[0]['timestamp']]

            if outliers_coordinates.empty and error_coordinates.empty:
                # no outlier, no error, no problem
                pass
            elif error_coordinates.empty:
                # some outliers, but generally no massive issue.
                # if the last data of the month is ok, considering it to be a glitch or temporary move,
                # just log a warning saying that outliers between X and Y.
                # if the last (of the month) is not ok but the last (of the full data) is, also temporary move
                # (this is necessary in cases where the last data of a month is incorrect, otherwise that month will be skipped forever
                # if the last is not ok, skip with an error and say that the data download will not resume at that
                # site until buoy is back where it should be (in general it is only for one day or 2)
                if (diff_lat_last < limit_outlier and diff_lon_last < limit_outlier):
                    message_add_warning(source_id,
                        f"Outliers (<10km) between {first_outlier} and {last_outlier}, but buoy back at location.")

                    # list_warning_sites[f"{source_id} ( {site_name} )"] = \
                    #     (f"Outliers (<10km) between {first_outlier} and {last_outlier}, but buoy back at location.")
                elif (diff_lat_last_api < limit_outlier and diff_lon_last_api < limit_outlier):
                    message_add_warning(source_id,
                        f"Outliers (<10km) between {first_outlier} and {last_outlier}, but buoy back at location during following month(s).")

                else:
                    if partial_data_outlier.empty:
                        pass
                    else:
                        template_dirpath = config.conf_dirpath
                        process_wave_dataframe(partial_data_outlier, source_id, template_dirpath, OUTPUT_PATH,
                                               incoming_path)

                    message_add_error(source_id,
                        f"Last data point ({last_outlier}) is an outlier (<10km). "
                        f"Data until {first_outlier} has been downloaded, but download for later data, will only "
                        f"resume when buoy is back at location."
                    )

                    return

            else:
                # coordinates are erroneous (>limit_error or 10km) generally means there is an issue with location
                # if the last coordinate is good and the difference between first and last error is less than 2 days,
                # it indicates that the buoy was moved and placed back (possibly to clean or do punctual repairs).
                # A warning is logged asking to contact facility to check and the data download goes as usual
                # if the last coordinates is not good but difference is less than 7 days,
                # does not download and gives error "check again after one week)
                # if the coordinates are erroneous for more than a week, fully stops the download and will require manual input
                if time_error.days < 7 and ((diff_lat_last < limit_outlier and diff_lon_last < limit_outlier) or
                                            (diff_lat_last_api < limit_outlier and diff_lon_last_api < limit_outlier)):

                    message_add_warning(source_id,
                        f"Coordinates errors (>10km) between {first_error_coordinates} and {last_error_coordinates}, "
                        f"but buoy back at location (within a week of first incidence). "
                        f"This usually indicates the buoy was moved to land for cleaning or repairs. "
                        f"The data has been downloaded nonetheless, monitor carefully for future errors."
                    )
                else:
                    if partial_data_error.empty:
                        pass
                    else:
                        template_dirpath = config.conf_dirpath
                        process_wave_dataframe(partial_data_error, source_id, template_dirpath, OUTPUT_PATH,
                                               incoming_path)

                        message_add_error(source_id,
                            f"Coordinates errors (>10km) since {first_error_coordinates}. "
                            f" Data until {first_error_coordinates} has been downloaded, but download for later data "
                            f"will not occur until buoy is back at location (within a week) or coordinates rectified "
                            f"(current coordinates of API are: lat: {error_coordinates.iloc[-1]['latitude']}"
                            f", lon: {error_coordinates.iloc[-1]['longitude']}).")
                        return

                    if time_error.days < 7:
                        message_add_error(source_id,
                            f"Coordinates errors (>10km) since {first_error_coordinates}. "
                            f"The download has been stopped until buoy is back at location (within a week) or coordinates rectified "
                            f"(current coordinates of API are: lat: {error_coordinates.iloc[-1]['latitude']}"
                            f" lon: {error_coordinates.iloc[-1]['longitude']})."
                        )
                        return
                    else:
                        message_add_error(source_id,
                            f"Coordinates errors (>10km) from {first_error_coordinates} to {last_error_coordinates}. "
                            f" The download has been stopped since {first_error_coordinates}. "
                            f"Please contact {sources_id_metadata[source_id]['institution']} to check buoy, or "
                            f"manually change the deployment start date."
                            f"(current coordinates of API are: lat: {error_coordinates.iloc[-1]['latitude']}"
                            f", lon: {error_coordinates.iloc[-1]['longitude']})."
                        )
                        return

            template_dirpath = config.conf_dirpath
            process_wave_dataframe(data, source_id, template_dirpath, OUTPUT_PATH, incoming_path)


def message_add_warning(source_id, message: str):
    sources_id_metadata = ardc_lookup.get_sources_id_metadata()
    site_name = sources_id_metadata[source_id]['site_name']
    list_warning_sites[f"{source_id} ( {site_name} )"] = message
    LOGGER.info(message)


def message_add_error(source_id, message: str):
    sources_id_metadata = ardc_lookup.get_sources_id_metadata()
    site_name = sources_id_metadata[source_id]['site_name']
    list_errors_sites[f"{source_id} ( {site_name} )"] = message
    LOGGER.error(message)


def message_final_logger(type: str):
    # creating a message(s) for successful, errors and/or warnings, to be displayed at end of log and/or notified (email)
    message_final = '\n \n ******************** \n \n' + str(datetime.datetime.now()) + ' : \n'
    message_error = ''
    message_warning = ''

    if not list_errors_sites:
        message_final = message_final + 'The data download was completed successfully'
    else:
        message_error = message_error + 'Partial data download. The following buoys were skipped due to errors:\n' + ",\n".join(
            "{!r}: {!r}".format(k, v) for k, v in list_errors_sites.items())
        message_final = message_final + message_error

    if not list_warning_sites:
        pass
    else:
        message_warning = message_warning + '\n \nThe following warnings were raised: \n' + ",\n".join(
            "{!r}: {!r}".format(k, v) for k, v in list_warning_sites.items()) + (
                              "\n  * Note that 'deployment start date missing' usually denotes a buoy IMOS does not "
                              "handle anymore but could indicate missing metadata.")
        message_final = message_final + message_warning

    message_final = message_final + '\n \n ******************** \n \n'

    if type == "error":
        return message_error
    elif type == "warning":
        return message_warning
    else:
        return message_final

def check_unique_ids(sources_id_metadata):
    # check for duplicates
    dupli_id = []
    dupli_name = []
    unique_source_id = []
    unique_site_name = []

    for source_id in sources_id_metadata.keys():
        if source_id not in unique_source_id:
            unique_source_id.append(source_id)
        else:
            dupli_id.append(source_id)
            continue
        site_name = sources_id_metadata[source_id]['site_name']

        if site_name not in unique_site_name:
            unique_site_name.append(site_name)
        else:
            dupli_name.append(source_id)

    if not dupli_id:
        pass
    else:
        for source_id in dupli_id:
            unique_source_id.remove(source_id)
            message_add_error(source_id, "The spotter id is duplicated in metadata and data was not downloaded.")

    if not dupli_name:
        pass
    else:
        for source_id in dupli_name:
            #   # this bit considers that a duplicated name is nota problem, but sends a warning.
            #   # if the error is preferred, use the commented code instead.

            message_add_warning(source_id,
                "The location name is duplicated, the data was still downloaded. Please remove old deployment from metadata, and check for duplicates"
            )
            #   # if error., comment warning message above and uncomment the following
            # unique_source_id.remove(source_id)
            # message_add_error(source_id,
            #                   "The location name is duplicated and data was not downloaded for either. Please remove old deployment from metadata."
            #                 )

    return(unique_source_id)


if __name__ == "__main__":

    vargs = args()

    # set up logging
    IMOSLogging().logging_start(os.path.join(vargs.output_path, 'process.log'))
    global LOGGER
    LOGGER = logging.getLogger(__name__)

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

    list_errors_sites = {}
    list_warning_sites = {}

    # check for duplicates:
    unique_source_id = check_unique_ids(sources_id_metadata)

    for source_id in unique_source_id:
        try:
            process_wave_source_id(source_id, incoming_path=vargs.incoming_path)
        except Exception as e:
            message_add_error(source_id, e)

    LOGGER.info(message_final_logger(type="final"))
    # LOGGER.info(message_final_logger(type="error"))
    #   # The message_final can be used in either sumo logic or notifications.


