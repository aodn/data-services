#!/bin/env python
# -*- coding: utf-8 -*-
import sys,threading,os
from configobj import ConfigObj  # install http://pypi.python.org/pypi/configobj/
from subroutines.soop_xbt_realtime_processSBD import soop_xbt_realtime_processSBD

if __name__ == "__main__":

    # csiro ftp config
    csiro_ftp_address           = os.environ.get('csiro_ftp_address')
    csiro_ftp_subdir            = os.environ.get('csiro_ftp_subdir')
    csiro_ftp_username          = os.environ.get('csiro_ftp_username')
    csiro_ftp_password          = os.environ.get('csiro_ftp_password')
    csiro_ftp_filetype          = os.environ.get('csiro_ftp_filetype')

    # local storage
    temporaryDataFolderUnsorted = os.environ.get('temporary_data_folder_unsorted_xbt_path')
    temporaryDataFolderSorted   = os.environ.get('temporary_data_folder_sorted_xbt_path')


    # download SOOP data from csiro's FTP
    try:
        cmd =  ('lftp'+ \
            ' -e \'mirror ' + csiro_ftp_subdir +' '+  temporaryDataFolderUnsorted + '\' ' +\
            csiro_ftp_address + '<<EOF')
        msg = os.system(cmd)
    except Exception, e:
        print str(e)


    processSBD = soop_xbt_realtime_processSBD()
    try:
        processSBD.processFiles(temporaryDataFolderUnsorted)
    except Exception, e:
        print str(e)
        pass
