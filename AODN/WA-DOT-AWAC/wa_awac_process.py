#!/usr/bin/env python
import argparse
import errno
import glob
import os
import sys
import tempfile
import traceback

from awac_library.common_awac import ls_txt_files, metadata_parser
from awac_library.current_parser import gen_nc_current_deployment
from awac_library.status_parser import gen_nc_status_deployment
from awac_library.temp_parser import gen_nc_temp_deployment
from awac_library.tide_parser import gen_nc_tide_deployment
from awac_library.wave_parser import gen_nc_wave_deployment
from imos_logging import IMOSLogging

""" TODO
check timezone, UTC date ...
QC mapping
wave, north magnetic ??
wave significant height from pressure sensor ? or acoustic sensor ?
is data already calibrated with status data?

check for Notes.txt and add it to the NetCDF
exemple JUR03_Text/JUR0304/WAVE
"""


def process_station(station_path, output_path, data_type='WAVE'):
    # station path folders ALL finish with *_Text
    if not os.path.basename(os.path.normpath(station_path)).endswith('_Text'):
        raise ValueError('{station_path} is not valid as not finishing with \'_Text\' string'.format(
            station_path=os.path.basename(station_path))
        )

    metadata_file = ls_txt_files(station_path)
    if not metadata_file:
        logger.warning('{station_path} does not have a \'_metadata.txt\' file in its path '.format(
            station_path=os.path.basename(station_path))
        )
        return

    if not metadata_file[0].endswith('_metadata.txt'):
        logger.warning('{station_path} does not have a \'_metadata.txt\' file in its path '.format(
            station_path=os.path.basename(station_path))
        )
        return

    metadata_location, location_info = metadata_parser(metadata_file[0])
    metadata = [metadata_location, location_info]

    for deployment in metadata_location.index.values:
        deployment_path = os.path.join(station_path, deployment)
        if not os.path.exists(deployment_path):
            raise OSError(
                errno.ENOENT, os.strerror(errno.ENOENT), deployment_path)

        # try catch to keep on processing the rest of deployments in case on deployment is corrupted
        try:
            if data_type == "WAVE":
                output_nc_path = gen_nc_wave_deployment(deployment_path, metadata, output_path=output_path)
            elif data_type == "TIDE":
                output_nc_path = gen_nc_tide_deployment(deployment_path, metadata, output_path=output_path)
            elif data_type == "TEMPERATURE":
                output_nc_path = gen_nc_temp_deployment(deployment_path, metadata, output_path=output_path)
            elif data_type == "CURRENT":
                output_nc_path = gen_nc_current_deployment(deployment_path, metadata, output_path=output_path)
            elif data_type == "STATUS":
                output_nc_path = gen_nc_status_deployment(deployment_path, metadata, output_path=output_path)

            logger.info('Created {nc}'.format(nc=output_nc_path))
        except Exception, e:
            logger.error(str(e))
            logger.error(traceback.print_exc())


def args():
    """
    define the script arguments
    :return: vargs
    """
    parser = argparse.ArgumentParser(description=
                                     'Creates FV01 NetCDF files (WAVE, TIDES...) from full WA_AWAC dataset.\n '
                                     'Prints out the path of the new locally generated FV01 file.')
    parser.add_argument('-i', "--wave-dataset-org-path",
                        dest='dataset_path',
                        type=str,
                        default='',
                        help="path to original wave dataset",
                        required=True)
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
    ./wa_awac_process -i $ARCHIVE_DIR/AODN/Dept-Of-Transport_WA_WAVES
    """
    vargs = args()
    station_ls = filter(lambda f: os.path.isdir(f), glob.glob('{dir}/*'.format(dir=vargs.dataset_path)))

    global logger
    logger = IMOSLogging().logging_start(os.path.join(vargs.output_path, 'process.log'))

    for station_path in station_ls:
        if station_path.endswith('_Text'):
            try:
                site_name = os.path.basename(station_path)
                logger.info('Processing WAVES for {station_path}'.format(station_path=site_name))
                process_station(station_path, vargs.output_path, data_type='WAVE')

                logger.info('Processing TIDES for {station_path}'.format(station_path=site_name))
                process_station(station_path, vargs.output_path, data_type='TIDE')

                logger.info('Processing TEMP for {station_path}'.format(station_path=site_name))
                process_station(station_path, vargs.output_path, data_type='TEMPERATURE')

                logger.info('Processing CURRENT for {station_path}'.format(station_path=site_name))
                process_station(station_path, vargs.output_path, data_type='CURRENT')

                logger.info('Processing STATUS for {station_path}'.format(station_path=site_name))
                process_station(station_path, vargs.output_path, data_type='STATUS')
            except Exception, e:
                logger.error(str(e))
                logger.error(traceback.print_exc())
