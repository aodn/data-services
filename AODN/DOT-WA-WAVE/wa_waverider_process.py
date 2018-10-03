#!/usr/bin/env python
import argparse
import errno
import os
import pandas as pd
import shutil
import sys
import tempfile
import traceback

from waverider_library.common_waverider import ls_txt_files, ls_ext_files, download_site_data, \
    retrieve_sites_info_waverider_kml
from waverider_library.wave_parser import gen_nc_wave_deployment

from imos_logging import IMOSLogging

""" TODO

"""


def process_station(station_path, output_path, site_info, data_type='WAVE'):
    metadata_files = ls_txt_files(station_path)

    list_dir_station = [x for x in os.listdir(station_path) if os.path.isdir(os.path.join(station_path, x))]
    data_files = ls_ext_files(os.path.join(station_path, list_dir_station[0]), '.xls')
    data_files.append(ls_ext_files(os.path.join(station_path, list_dir_station[0]), '.xlsx'))

    for data_file in data_files:
        # try catch to keep on processing the rest of deployments in case on deployment is corrupted
        try:
            output_nc_path = gen_nc_wave_deployment(data_file, output_path=output_path)
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
                                     'Creates FV01 NetCDF files (WAVE from full WA_WAVERIDER dataset.\n '
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
    Processing of the full WAVERIDER dataset from DOT-WA
    ./wa_waverider_process
    """
    vargs = args()

    global logger
    logger = IMOSLogging().logging_start(os.path.join(vargs.output_path, 'process.log'))

    sites_info = retrieve_sites_info_waverider_kml()
    for _, site_code in enumerate(sites_info):
        site_info = sites_info[site_code]
        temporary_data_path = download_site_data(site_info)
        try:
            logger.info('Processing WAVES for {station_path}'.format(station_path=site_info['site_name']))
            process_station(temporary_data_path, vargs.output_path, site_info, data_type='WAVE')

            shutil.rmtree(os.path.dirname(temporary_data_path))

        except Exception, e:
            logger.error(str(e))
            logger.error(traceback.print_exc())
            shutil.rmtree(os.path.dirname(temporary_data_path))
