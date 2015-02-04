#!/bin/env python
# -*- coding: utf-8 -*-
import sys,threading,os
from configobj import ConfigObj  # install http://pypi.python.org/pypi/configobj/
from subroutines.soop_bom_asf_sst_Filsort import soop_bom_asf_sst_Filsort

if __name__ == "__main__":

    pathname                    = os.path.dirname(sys.argv[0])
    pythonScriptPath            = os.path.abspath(pathname)

    configFilePath              = pythonScriptPath
    config                      = ConfigObj(configFilePath + os.path.sep + "config.txt")

    # bom ftp config
    bom_ftp_address             = config.get('bom_ftp.address')
    bom_ftp_subdir              = config.get('bom_ftp.subdir')
    bom_ftp_username            = config.get('bom_ftp.username')
    bom_ftp_password            = config.get('bom_ftp.password')
    bom_ftp_filetype            = config.get('bom_ftp.filetype')

    # local storage
    temporaryDataFolderUnsorted = config.get('temporaryDataFolderUnsorted_ASF_SST.path')
    temporaryDataFolderSorted   = config.get('temporaryDataFolderSorted_ASF_SST.path')


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
