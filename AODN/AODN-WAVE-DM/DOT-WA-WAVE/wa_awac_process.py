#!/usr/bin/env python
import argparse
import glob
import os
import pickle
import shutil
import sys
import tempfile
import traceback

import pandas as pd

from awac_library.common_awac import ls_txt_files, metadata_parser, download_site_data, retrieve_sites_info_awac_kml, \
    WIP_DIR, PICKLE_FILE, load_pickle_db
from awac_library.current_parser import gen_nc_current_deployment
from awac_library.status_parser import gen_nc_status_deployment
from awac_library.temp_parser import gen_nc_temp_deployment
from awac_library.tide_parser import gen_nc_tide_deployment
from awac_library.wave_parser import gen_nc_wave_deployment
from imos_logging import IMOSLogging

""" TODO
wave, north magnetic ?? still unsure
wave significant height from pressure sensor ? or acoustic sensor ?
is data already calibrated with status data?

- find data already downloaded , to be updated ...
- process data from binary file ? wpr parser similar to toolbox ? could be good for bad text files
"""


def process_station(site_path, output_path, site_info):
    """
    :param site_path:
    :param output_path:
    :param site_info:
    :return:
    """
    station_ls = filter(lambda f: os.path.isdir(f), glob.glob('{dir}/*'.format(dir=site_path)))

    for station_path in station_ls:
        if site_info['site_code'] not in os.path.basename(os.path.normpath(station_path)):
            raise ValueError('{station_path} is not valid as not finishing with \'_Text\' string'.format(
                station_path=os.path.basename(station_path))
            )
        metadata_file = ls_txt_files(station_path)
        deployment_ls = filter(lambda f: os.path.isdir(f), glob.glob('{dir}/*'.format(dir=station_path)))

        use_kml_metadata = False
        if not metadata_file:
            use_kml_metadata = True
        elif not metadata_file[0].endswith('_metadata.txt'):
            use_kml_metadata = True

        if use_kml_metadata:
            logger.warning('{station_path} does not have a \'_metadata.txt\' file in its path.\n Using metadata'
                           'from KML instead'.format(station_path=os.path.basename(station_path))
                           )
            # since no metadata file, we assume (correctly) that the folder name is equal to the site code value
            list_dir_stations = [x for x in os.listdir(station_path) if os.path.isdir(os.path.join(station_path, x))]
            metadata_location = pd.DataFrame(index=list_dir_stations,
                                             columns=['instrument_maker', 'instrument_model', 'comment'])
            metadata_location['instrument_maker'] = ['NORTEK'] * len(list_dir_stations)
            metadata_location['instrument_model'] = ['1 MHz AWAC'] * len(list_dir_stations)
            metadata_location['comment'] = [''] * len(list_dir_stations)

            location_info = site_info

        else:
            metadata_location, location_info = metadata_parser(metadata_file[0])

        metadata = [metadata_location, location_info]

        """
        Creating a list of deployments, between metadata file and folders
        Deployment path is not always what is should be from the metadata file. So looking to match most likely 
        string
        Also metadata file can be corrupted and have the same deployment written twice, and missing some 
        """
        deployment_folder_ls = [os.path.basename(x.split(' ')[0]) for x in deployment_ls]  # removing possible parts after white space
        deployment_metadata_ls = metadata_location.index.values
        if len(deployment_folder_ls) == len(set(metadata_location.index.values)):
            deployment_ls_iterate = metadata_location.index.values
        elif len(deployment_folder_ls) > len(set(metadata_location.index.values)):
            deployment_ls_iterate = deployment_folder_ls  # in that case

        for deployment in deployment_ls_iterate:
            """
            deployment path is not always what is should be from the metadata file. So looking to match most likely 
            string
            """

            deployment_path = [s for s in deployment_ls if deployment in s][0]
            logger.info("Processing deployment: {deployment}".format(deployment=deployment))

            if not os.path.exists(deployment_path):
                logger.error("{path} deployment does not exist".format(path=deployment_path))
                err = True
            else:
                # try catch to keep on processing the rest of deployments in case one deployment is corrupted
                try:
                    output_nc_path = gen_nc_wave_deployment(deployment_path, metadata, site_info, output_path=output_path)
                    logger.info('NetCDF created {nc}'.format(nc=output_nc_path))
                except Exception, err:
                    logger.error(str(err))
                    logger.error(traceback.print_exc())

                try:
                    output_nc_path = gen_nc_tide_deployment(deployment_path, metadata, site_info, output_path=output_path)
                    logger.info('NetCDF created {nc}'.format(nc=output_nc_path))
                except Exception, err:
                    logger.error(str(err))
                    logger.error(traceback.print_exc())

                try:
                    output_nc_path = gen_nc_temp_deployment(deployment_path, metadata, site_info, output_path=output_path)
                    logger.info('NetCDF created {nc}'.format(nc=output_nc_path))
                except Exception, err:
                    logger.error(str(err))
                    logger.error(traceback.print_exc())

                try:
                    output_nc_path = gen_nc_current_deployment(deployment_path, metadata, site_info, output_path=output_path)
                    logger.info('NetCDF created {nc}'.format(nc=output_nc_path))
                except Exception, err:
                    logger.error(str(err))
                    logger.error(traceback.print_exc())

                try:
                    output_nc_path = gen_nc_status_deployment(deployment_path, metadata, site_info, output_path=output_path)
                    logger.info('NetCDF created {nc}'.format(nc=output_nc_path))
                except Exception, err:
                    logger.error(str(err))
                    logger.error(traceback.print_exc())


    # once a station has been successfully processed, we log the md5 of the zip file to not reprocess it
    # on the next run
    if 'err' not in locals():
        previous_download = load_pickle_db(PICKLE_FILE)
        if previous_download is None:
            previous_download = dict()

        with open(PICKLE_FILE, 'wb') as p_write:
            previous_download[site_info['text_zip_url']] = site_info['zip_md5']
            pickle.dump(previous_download, p_write)


def args():
    """
    define the script arguments
    :return: vargs
    """
    parser = argparse.ArgumentParser(description=
                                     'Creates FV01 NetCDF files (WAVE, TIDES...) from full WA_AWAC dataset.\n '
                                     'Prints out the path of the new locally generated FV01 file.')
    parser.add_argument('-o', '--output-path',
                        dest='output_path',
                        type=str,
                        default=None,
                        help="output directory of FV01 netcdf file. (Optional)",
                        required=False)
    vargs = parser.parse_args()

    if vargs.output_path is None:
        vargs.output_path = tempfile.mkdtemp()

    if not os.path.exists(vargs.output_path):
        raise ValueError('{path} not a valid path'.format(path=vargs.output_path))
        sys.exit(1)

    return vargs


if __name__ == "__main__":
    """
    Processing of the full WA dataset
    ./wa_awac_process
    """
    vargs = args()

    global logger
    logger = IMOSLogging().logging_start(os.path.join(vargs.output_path, 'process.log'))
    if not os.path.exists(WIP_DIR):
        os.makedirs(WIP_DIR)

    sites_info = retrieve_sites_info_awac_kml()
    for _, site_code in enumerate(sites_info):
        site_info = sites_info[site_code]
        temporary_data_path, site_info = download_site_data(site_info)  # returned site_info has extra md5 info

        site_name = site_info['site_code']
        try:
            if site_info['already_uptodate']:
                logger.info('{station_path} already up to date'.format(station_path=site_name))
                shutil.rmtree(temporary_data_path)
                continue

            process_station(temporary_data_path, vargs.output_path, site_info)

        except Exception, e:
            logger.error(str(e))
            logger.error(traceback.print_exc())

        if os.path.exists(temporary_data_path):
            shutil.rmtree(temporary_data_path)

