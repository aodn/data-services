#!/bin/env python
# -*- coding: utf-8 -*-
import os
import datetime
import re

# function to read lftp output and write log file for incoming handler
def read_lftp_log(lftp_log):
    lines = [line.rstrip('\n') for line in open(lftp_log)]

    list=[]
    for line in lines:
        m = re.search(bom_ftp_subdir[1:] + '/.*/IMOS_SOOP-(.+?).nc', line)
        if m:
            found = temporaryDataFolderUnsorted + '/' + m.group(0)[len(bom_ftp_subdir):]
            if os.path.isfile(found):
                list.append(found) # append only if file exist on filesystem

    thefile = open(temporaryDataFolderUnsorted+'/incoming.log', "w")
    for item in list:
        thefile.write("%s\n" % item)
    thefile.close

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
    today = str(datetime.date.today())
    try:
        lftp_log = temporaryDataFolderUnsorted + '/lftp_mirror-' + today + '.log'
        cmd =  ('lftp -u '+ \
                 bom_ftp_username +',' +\
                 bom_ftp_password +\
                 ' -e \'mirror --log=' + lftp_log +' --only-newer ' + bom_ftp_subdir +' '+  temporaryDataFolderUnsorted + '\' ' +\
                 bom_ftp_address  + '<<EOF')
        msg = os.system(cmd)

        # write log file for incoming handler
        read_lftp_log(lftp_log)

    except Exception, e:
        print str(e)

