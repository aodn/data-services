#! /usr/bin/env python
#
# Group raw acoustic recording files by UT day and zip into
# daiyl archives.

import sys, os
from datetime import datetime, timedelta
from acoustic.acousticUtils import recordingStartTime
import argparse


# parse command line
parser = argparse.ArgumentParser()
parser.add_argument('recList', help='Text file listing files to sort')
args = parser.parse_args()
recList = open(args.recList)


zipAdd = 'zip --must-match '
zipTest = 'zip --test '

prevZipFile = ''
prevZipList = []

# for each recording...
for rec in recList:
    rec = rec.strip()
    recTime = recordingStartTime(rec)
    dateStr = recTime.strftime('%Y%m%d')
    zipFile = dateStr+'.zip'

    if prevZipFile <> zipFile:  
        # check previous zip file before proceeding
        if prevZipFile:
            cmd = zipTest + prevZipFile
            if os.system(cmd):
                print 'zip file %s failed test!' % prevZipFile
                exit()        
        # ... and delete recordings that were successfully added
        cmd = 'rm ' + ' '.join(prevZipList)
        if os.system(cmd):
            print 'Failed to delete files!'

        prevZipFile = zipFile
        print '\n%s:' % zipFile

    cmd = ' '.join([zipAdd, zipFile, rec])
    if os.system(cmd):
        print 'error zipping files!'
        exit()
    prevZipList.append(rec)


cmd = zipTest + prevZipFile
if os.system(cmd):
    print 'zip file %s failed test!' % prevZipFile
    exit()        
