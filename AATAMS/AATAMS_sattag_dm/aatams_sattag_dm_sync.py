#!/usr/bin/env python
# -*- coding: utf-8 -*-

import argparse
import datetime
import os
import shutil
from tempfile import mkstemp

from tendo import singleton

from imos_logging import IMOSLogging
from lftp_sync import LFTPSync
from util import list_files_recursively


def main(force_reprocess_all=False):
    # will sys.exit(-1) if other instance is running
    me = singleton.SingleInstance()
    wip_soop_path    = os.path.join(os.environ['WIP_DIR'], 'AATAMS_SATTAG_DM')
    lftp_output_path = os.path.join(wip_soop_path, 'zipped')
    log_filepath     = os.path.join(wip_soop_path, 'aatams_sattag_dm.log')
    logging          = IMOSLogging()
    logger           = logging.logging_start(log_filepath)

    if not os.path.exists(lftp_output_path):
        os.makedirs(lftp_output_path)

    lftp_access = {
        'ftp_address': os.environ['IMOS_PO_CREDS_AATAMS_FTP_ADDRESS'],
        'ftp_subdir': '/',
        'ftp_user': os.environ['IMOS_PO_CREDS_AATAMS_FTP_USERNAME'],
        'ftp_password': os.environ['IMOS_PO_CREDS_AATAMS_FTP_PASSWORD'],
        'ftp_exclude_dir': '',
        'lftp_options': '--only-newer --exclude-glob TDR/* --exclude-glob *_ODV.zip',
        'output_dir': lftp_output_path
    }

    lftp = LFTPSync()
    logger.info('Download new AATAMS SATTAG DM files')
    lftp.lftp_sync(lftp_access)

    # optional function argument to force the reprocess of all ZIP files
    if force_reprocess_all:
        manifest_list = list_files_recursively(lftp_output_path, '*.zip')
    else:
        manifest_list = lftp.list_new_files_path(check_file_exist=True)

    fd, manifest_file = mkstemp()
    for zip_file in manifest_list:
        if not(zip_file == []):
            os.write(fd, '%s\n' % zip_file)
    os.close(fd)
    os.chmod(manifest_file, 0o664)  # since msktemp creates 600 for security

    logger.info('ADD manifest to INCOMING_DIR')
    manifest_file_inco_path = os.path.join(os.environ['INCOMING_DIR'], 'AATAMS',
                                           'AATAMS_SATTAG_DM',
                                           'aatams_sattag_dm_lftp.%s.manifest' % datetime.datetime.utcnow().strftime('%Y%m%d-%H%M%S'))
    if not os.path.exists(manifest_file_inco_path):
        shutil.copy(manifest_file, manifest_file_inco_path)
    else:
        logger.warning('File already exist in INCOMING_DIR')
        exit(1)

    lftp.close()
    logging.logging_stop()


def parse_arg():
    """
    create optional script arg -f to to force the reprocess of all zip files
    already downloaded
    """
    parser = argparse.ArgumentParser()
    parser.add_argument("-f", "--force-reprocess",
                        help="reprocess all zip files", action="store_true")
    args = parser.parse_args()

    return args


if __name__ == "__main__":
    """
    ./aatams_sattag_dm_sync.py -h       Help
    ./aatams_sattag_dm_sync.py -f       Force reprocess ZIP files
    ./aatams_sattag_dm_sync.py          Normal process
    """
    os.umask(0o002)
    args = parse_arg()
    if args.force_reprocess:
        main(force_reprocess_all=True)
    else:
        main()  # default value
