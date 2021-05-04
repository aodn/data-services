#!/usr/bin/env python
import argparse
import glob
import os
import sys
import tempfile
import traceback

from bom_wave_library.bom_wave_parser import gen_nc_bom_wave_dm_deployment, metadata_info
from bom_wave_library.common import ls_ext_files
from imos_logging import IMOSLogging


def process_station(station_path, output_path):
    """
    process of station folder containing csv, xls, xlsx files
    :param station_path:
    :param output_path:
    :return: None
    """
    metadata = metadata_info(station_path)

    files_to_process = [ls_ext_files(station_path, '.csv'), ls_ext_files(station_path, '.xls'),
                        ls_ext_files(station_path, '.xlsx'), ls_ext_files(station_path, '.txt')]

    files_to_process = [item for sublist in files_to_process for item in sublist]  # create a flat list
    for filepath in files_to_process:
        metadata['original_filename'] = os.path.basename(filepath)
        logger.info('Processing {filepath}'.format(filepath=os.path.basename(filepath)))
        try:
            output_nc_path = gen_nc_bom_wave_dm_deployment(filepath, metadata, output_path)
            logger.info('NetCDF created at {output_nc_path}'.format(output_nc_path=output_nc_path))
        except Exception as e:
            logger.error(str(e))
            logger.error(traceback.print_exc())


def args():
    """
    define the script arguments
    :return: vargs
    """
    parser = argparse.ArgumentParser(description='Creates FV01 NetCDF files from BOM WAVE Delayed Mode dataset.\n '
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
        try:
            os.makedirs(vargs.output_path)
        except Exception:
            raise ValueError('{path} not a valid path'.format(path=vargs.output_path))
            sys.exit(1)

    return vargs


if __name__ == "__main__":
    """
    Processing of the full BOM WAVE DM dataset
    ./bom_wave_dm_process -i $ARCHIVE_DIR/AODN/BOM_WAVE_DM
    """

    vargs = args()
    station_ls = filter(lambda f: os.path.isdir(f), glob.glob('{dir}/*'.format(dir=vargs.dataset_path)))

    logger = IMOSLogging().logging_start(os.path.join(vargs.output_path, 'process.log'))

    for station_path in station_ls:
        logger.info('Processing WAVES for {station_path}'.format(station_path=os.path.basename(station_path)))
        process_station(station_path, vargs.output_path)

    logger.info('End of processing')
