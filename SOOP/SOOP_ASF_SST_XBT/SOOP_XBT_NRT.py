#!/usr/bin/env python
# -*- coding: utf-8 -*-

import argparse
import os
import shutil
from tempfile import mkstemp

from tendo import singleton

from imos_logging import IMOSLogging
from lftp_sync import LFTPSync
from subroutines.soop_xbt_realtime_processSBD import \
    soop_xbt_realtime_processSBD
from util import list_files_recursively


def main(force_reprocess_all=False):
    # will sys.exit(-1) if other instance is running
    me = singleton.SingleInstance()
    wip_soop_path    = os.path.join(os.environ['WIP_DIR'], 'SOOP',
                                    'SOOP_XBT_ASF_SST')
    lftp_output_path = os.path.join(wip_soop_path, 'data_unsorted', 'XBT',
                                    'sbddata')
    csv_output_path  = os.path.join(wip_soop_path, 'data_sorted', 'XBT',
                                    'sbddata')
    log_filepath     = os.path.join(wip_soop_path, 'soop_xbt.log')
    logging          = IMOSLogging()
    logger           = logging.logging_start(log_filepath)

    lftp_access = {
        'ftp_address'     : os.environ['IMOS_PO_CREDS_CSIRO_IT_FTP_ADDRESS'],
        'ftp_subdir'      : '/',
        'ftp_user'        : os.environ['IMOS_PO_CREDS_CSIRO_IT_FTP_USERNAME'],
        'ftp_password'    : os.environ['IMOS_PO_CREDS_CSIRO_IT_FTP_PASSWORD'],
        'ftp_exclude_dir' : '',
        'lftp_options'    : '--only-newer',
        'output_dir'      : lftp_output_path,
        }

    lftp = LFTPSync()
    logger.info('Download new SOOP XBT NRT files')
    lftp.lftp_sync(lftp_access)

    # optional function argument to force the reprocess of all sbd files
    if force_reprocess_all:
        list_new_files = list_files_recursively(lftp_output_path, '*.sbd')
    else:
        list_new_files = lftp.list_new_files_path(check_file_exist=True)

    logger.info('Convert SBD files to CSV')
    processSBD    = soop_xbt_realtime_processSBD()
    manifest_list = []
    for f in list_new_files:
        if f.endswith(".sbd"):
            try:
                csv_file = processSBD.handle_sbd_file(f, csv_output_path)
                if csv_file not in manifest_list:
                    manifest_list.append(csv_file)
            except Exception, e:
                logger.error(str(e))
                pass

    fd, manifest_file = mkstemp()
    for csv_file in manifest_list:
        if not(csv_file == []):
            os.write(fd, '%s\n' % csv_file)
    os.close(fd)

    logger.info('ADD manifest to INCOMING_DIR')
    manifest_file_inco_path = os.path.join(os.environ['INCOMING_DIR'], 'SOOP',
                                           'XBT', 'NRT',
                                           'IMOS_SOOP-XBT_NRT_fileList.csv')
    if not os.path.exists(manifest_file_inco_path):
        shutil.copy(manifest_file, manifest_file_inco_path)
    else:
        logger.warning('File already exist in INCOMING_DIR')
        exit(1)

    lftp.close()
    logging.logging_stop()

def parse_arg():
    """
    create optional script arg -f to to force the reprocess of all SBD files
    already downloaded
    """
    parser = argparse.ArgumentParser()
    parser.add_argument("-f", "--force-reprocess",
                        help="reprocess all sdb files", action="store_true")
    args = parser.parse_args()

    return args


if __name__ == "__main__":
    """
    ./SOOP_XBT_NRT.py -h       Help
    ./SOOP_XBT_NRT.py -f       Force reprocess SBD files
    ./SOOP_XBT_NRT.py          Normal process
    """
    args = parse_arg()
    if args.force_reprocess:
        main(force_reprocess_all=True)
    else:
        main()  # default value
