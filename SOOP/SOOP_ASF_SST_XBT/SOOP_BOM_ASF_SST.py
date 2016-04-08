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
import fnmatch
import argparse

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
            product_incoming_path =  os.path.join( soop_incoming_dir, 'SST')
            shutil.copy2(line, product_incoming_path)
            logger.info('Copy to %s' % os.path.join(product_incoming_path,
                                                    os.path.basename(line)))

        elif re.search('.*/IMOS_SOOP-ASF_FMT(.+?).nc', line):
            product_incoming_path =  os.path.join( soop_incoming_dir, 'ASF', 'FMT')
            shutil.copy2(line, product_incoming_path)
            logger.info('Copy to %s' % os.path.join(product_incoming_path,
                                                   os.path.basename(line)))

        elif re.search('.*/IMOS_SOOP-ASF_MT(.+?).nc', line):
            product_incoming_path =  os.path.join( soop_incoming_dir, 'ASF', 'MT')
            shutil.copy2(line, product_incoming_path)
            logger.info('Copy to %s' % os.path.join(product_incoming_path,
                                                   os.path.basename(line)))
        else:
            continue

def parse_arg():
    """
    create optional script arg -f to to force the reprocess of all SBD files
    already downloaded
    """
    parser = argparse.ArgumentParser()
    parser.add_argument("-f", "--force-push-incoming",
                        help="force the push of all files alreay downloaded to the incoming dir. Does not download new ones", action="store_true")
    parser.add_argument("-r", "--reprocess-files-match-pattern", type=str, help="reprocess all files already downloaded matching a string pattern. '*SOOP-SST*' '*FHZI*' ... to the incoming dir", )
    args = parser.parse_args()

    return args

def push_files_pattern_match_incoming(filter_pattern):
    """
    find files already downloaded matching a certain pattern. And push these files
    to the incoming dir
    """
    list_files = []
    for root, dirnames, filenames in os.walk(output_data_folder):
        for filename in fnmatch.filter(filenames, filter_pattern):
            list_files.append(os.path.join(root, filename))

    if list_files is not None:
        move_soop_files_incoming_dir(list_files)


if __name__ == "__main__":
    """
    SOOP_BOM_ASF_SST.py
    SOOP_BOM_ASF_SST.py -f
    SOOP_BOM_ASF_SST.py -r *FHZI*
    SOOP_BOM_ASF_SST.py -r *ASF-MT*
    """
    me   = singleton.SingleInstance()
    # will sys.exit(-1) if other instance is running
    args = parse_arg()

    global output_data_folder
    output_data_folder = os.path.join(os.environ['WIP_DIR'], 'SOOP',
                                      'SOOP_XBT_ASF_SST', 'data_unsorted',
                                      'ASF_SST', 'ship')

    log_filepath = os.path.join(output_data_folder, 'soop_asf_sst.log')
    logging      = IMOSLogging()

    global logger
    logger       = logging.logging_start(log_filepath)
    logger.info('Process SOOP_ASF_SST')

    # handle scripts arguments
    if args.force_push_incoming:
        push_files_pattern_match_incoming('*.nc')

    elif args.reprocess_files_match_pattern:
        push_files_pattern_match_incoming(args.reprocess_files_match_pattern)

    else:
        list_new_files = download_lftp_dat_files()
        move_soop_files_incoming_dir(list_new_files)
        lftp.close()

    logging.logging_stop()
