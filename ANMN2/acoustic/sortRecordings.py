#! /usr/bin/env python
#
# Group raw acoustic recording files by UT day and zip into
# daiyl archives.

import sys, os
from datetime import datetime, timedelta
from acoustic.acousticUtils import recordingStartTime
import argparse


def makeZip(zipfile, fileList):
    # zip files
    cmd = ' '.join(['zip --must-match --test', zipfile] + fileList)
    if os.system(cmd) <> 0:
        print 'error zipping files!'
        exit() 
    # record filenames for later removal
    print >>log, '\n# ', zipfile
    print >>log, 'rm', '\nrm '.join(fileList)


# parse command line
parser = argparse.ArgumentParser()
parser.add_argument('recList', help='Text file listing files to sort')
args = parser.parse_args()
recList = open(args.recList).readlines()

log = open('done.rm', 'a', 0)
prevZipFile = ''
prevZipList = []

# for each recording...
while recList:
    rec = recList.pop(0).strip()
    recTime = recordingStartTime(rec)
    dateStr = recTime.strftime('%Y%m%d')
    zipFile = dateStr+'.zip'

    if prevZipFile <> zipFile and prevZipFile:
        makeZip(prevZipFile, prevZipList)
        prevZipList = []

    prevZipFile = zipFile
    prevZipList.append(rec)

makeZip(prevZipFile, prevZipList)

log.close()
