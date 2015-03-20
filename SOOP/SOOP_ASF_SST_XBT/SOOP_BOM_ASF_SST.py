#!/bin/env python
# -*- coding: utf-8 -*-
import sys,threading,os
from configobj import ConfigObj  # install http://pypi.python.org/pypi/configobj/
from subroutines.soop_bom_asf_sst_Filsort import soop_bom_asf_sst_Filsort

if __name__ == "__main__":

    # bom ftp config
    bom_ftp_address             = os.environ.get('bom_ftp_address')
    bom_ftp_subdir              = os.environ.get('bom_ftp_subdir')
    bom_ftp_username            = os.environ.get('bom_ftp_username')
    bom_ftp_password            = os.environ.get('bom_ftp_password')
    bom_ftp_filetype            = os.environ.get('bom_ftp_filetype')

    # local storage
    temporaryDataFolderUnsorted = os.environ.get('temporary_data_folder_unsorted_asf_sst_path')
    temporaryDataFolderSorted   = os.environ.get('temporary_data_folder_sorted_asf_sst_path')


    # download SOOP data from BOM's FTP
    try:
        cmd =  ('lftp -u '+ \
                 bom_ftp_username +',' +\
                 bom_ftp_password +\
                 ' -e \'mirror --only-newer ' + bom_ftp_subdir +' '+  temporaryDataFolderUnsorted + '\' ' +\
                 bom_ftp_address  + '<<EOF')
        msg = os.system(cmd)
    except Exception, e:
        print str(e)

    # Order downloaded data in temporaryDataFolderSorted folder
    filesort = soop_bom_asf_sst_Filsort()
    try:
      filesort.processFiles(temporaryDataFolderUnsorted ,temporaryDataFolderSorted, bom_ftp_filetype)
    except Exception, e:
      print "ERROR: uncaught error occured with FileSort " +temporaryDataFolderUnsorted + str(e)
      pass

    filesort.close()
