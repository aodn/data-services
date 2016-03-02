#!/usr/bin/env python
# -*- coding: utf-8 -*-
import os
import re
import sys
import shutil
from tendo import singleton
sys.path.insert(0, os.path.join(os.environ.get('DATA_SERVICES_DIR'), 'lib'))
from python.lftp_sync import LFTPSync
from python.imos_logging import IMOSLogging


def download_lftp_dat_files():
    """
    lftp download of the SOOP ASF SST. Only the files not in
    output_dir will be downloaded
    """
    lftp_access = {
        'ftp_address'     : os.environ['IMOS_PO_CREDS_BOM_FTP_ADDRESS'],
        'ftp_subdir'      : '/register/bom404/outgoing/IMOS/SHIPS',
        'ftp_user'        : os.environ['IMOS_PO_CREDS_BOM_FTP_USERNAME'],
        'ftp_password'    : os.environ['IMOS_PO_CREDS_BOM_FTP_PASSWORD'],
        'ftp_exclude_dir' : '',
        'lftp_options'    : '--only-newer',
        'output_dir'      : output_data_folder,
        }

    global lftp
    lftp = LFTPSync()

    if os.path.exists(os.path.join(output_data_folder, 'lftp_mirror.log')):
        return lftp.list_new_files_path_previous_log(lftp_access)

    lftp.lftp_sync(lftp_access)
    return lftp.list_new_files_path(check_file_exist=True)


def move_soop_files_incoming_dir(list_files):
    soop_incoming_dir = os.path.join(os.environ['INCOMING_DIR'], 'SOOP')

    for line in list_files:
        if re.search('.*/IMOS_SOOP-SST(.+?).nc', line):
            shutil.copy2(line, os.path.join( soop_incoming_dir, 'SST'))

        elif re.search('.*/IMOS_SOOP-ASF_FMT(.+?).nc', line):
            shutil.copy2(line, os.path.join( soop_incoming_dir, 'ASF', 'FMT'))

        elif re.search('.*/IMOS_SOOP-ASF_MT(.+?).nc', line):
            shutil.copy2(line, os.path.join( soop_incoming_dir, 'ASF', 'MT'))

        else:
            continue

        logger.info('Copy to INCOMING_DIR %s' % line)


if __name__ == "__main__":
    # will sys.exit(-1) if other instance is running
    me   = singleton.SingleInstance()

    global output_data_folder
    output_data_folder = os.path.join(os.environ['WIP_DIR'], 'SOOP',
                                      'SOOP_XBT_ASF_SST', 'data_unsorted',
                                      'ASF_SST', 'ship')

    log_filepath = os.path.join(output_data_folder, 'soop_asf_sst.log')
    logging      = IMOSLogging()

    global logger
    logger       = logging.logging_start(log_filepath)
    logger.info('Process SOOP_ASF_SST')

    list_new_files = download_lftp_dat_files()
    move_soop_files_incoming_dir(list_new_files)

    lftp.close()
    logging.logging_stop()
