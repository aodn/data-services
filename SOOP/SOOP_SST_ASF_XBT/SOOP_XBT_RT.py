#!/bin/env python
# -*- coding: utf-8 -*-
import sys,threading,os
from configobj import ConfigObj  # install http://pypi.python.org/pypi/configobj/
from subroutines.soop_xbt_realtime_processSBD import soop_xbt_realtime_processSBD

if __name__ == "__main__":
    
    pathname                    = os.path.dirname(sys.argv[0])        
    pythonScriptPath            = os.path.abspath(pathname)
    
    configFilePath              = pythonScriptPath  
    config                      = ConfigObj(configFilePath + os.path.sep + "config.txt")
    
    # csiro ftp config
    csiro_ftp_address           = config.get('csiro_ftp.address')
    csiro_ftp_subdir            = config.get('csiro_ftp.subdir')
    csiro_ftp_username          = config.get('csiro_ftp.username')
    csiro_ftp_password          = config.get('csiro_ftp.password')
    csiro_ftp_filetype          = config.get('csiro_ftp.filetype')
    
    # local storage
    temporaryDataFolderUnsorted = config.get('temporaryDataFolderUnsorted_XBT.path')
    temporaryDataFolderSorted   = config.get('temporaryDataFolderSorted_XBT.path')
    
    
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
 