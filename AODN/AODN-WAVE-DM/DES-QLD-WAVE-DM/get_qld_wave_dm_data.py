#!/usr/bin/env python
# -*- coding: utf-8 -*-
import argparse
import os
import traceback
import tempfile

from imos_logging import IMOSLogging
from lib.common import move_to_output_path, WIP_DIR
from lib.qld_metadata import package_metadata, retrieve_ls_package_resources, list_new_resources_to_dl, \
    list_package_names
from lib.qld_netcdf import generate_qld_netcdf

"""
Part of the RDC project is to get WAVE data from the Queensland Government web-service.
Files are downloaded from as a Json output, cleaned and transformed into NetCDF files.
"""


def args():
    """
    define the script arguments
    :return: vargs
    """
    parser = argparse.ArgumentParser(description=
                                     'Creates FV01 NetCDF files (WAVE, CURRENT...) from delayed mode Queensland Gov'
                                     'web-service.\n '
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


def process_site(package_name, output_dir_path):
    """
    Process all the resources for a package (ie all the 'deployments' for a site, 
    creating netcdf file output to output_dir_path
    :param package_name: string of package name to process
    :param output_dir_path: string of output dir path
    :return:
    """
    metadata = package_metadata(package_name)
    metadata['package_name'] = package_name  # add package_name to metadata
    package_resources = retrieve_ls_package_resources(package_name)  # list all resources

    resource_id_to_process = list_new_resources_to_dl(package_resources)  # find resources to download
    nc_file_path = []
    for resource_id in resource_id_to_process:
        try:
            nc_file_path.append(generate_qld_netcdf(resource_id, metadata, output_dir_path))
        except Exception as err:
            logger.error('Issue processing ressource_id {id}'.format(id=resource_id))
            logger.error('{err}'.format(err=err))
            logger.error(traceback.print_exc())

    return set(nc_file_path)


if __name__ == '__main__':
    vargs = args()
    if not os.path.exists(WIP_DIR):
        os.makedirs(WIP_DIR)

    logging = IMOSLogging()
    global logger
    logger = logging.logging_start(os.path.join(WIP_DIR, 'process.log'))

    package_names = list_package_names()
    nc_wip_dir = os.path.join(WIP_DIR, 'NetCDF')
    if not os.path.exists(nc_wip_dir):
        os.makedirs(nc_wip_dir)

    for package_name in package_names:
        try:
            ls_netcdf_path = process_site(package_name, nc_wip_dir)
            for nc in ls_netcdf_path:
                move_to_output_path(nc, vargs.output_path)
        except Exception, e:
            logger.error(str(e))
            logger.error(traceback.print_exc())

    logger.info('End of processing')
