#!/usr/bin/env python
# Returns the relative path to create for a modified SRS OC LJCO Weather Water Sampling
#
# author Laurent Besnard, laurent.besnard@utas.edu.au

import datetime
import os, sys
from netCDF4 import Dataset
import re

def removeCreationDateFromFilename(netcdfFilename):
    return re.sub('_C-.*$','.nc', netcdfFilename)

def createFileHierarchy(netcdfFilePath):
    netcdfFileObj = Dataset(netcdfFilePath, mode='r')
    siteCode      = netcdfFileObj.site_code
    title         = netcdfFileObj.title

    if not "LJCO weather and water sampling" in title:
        print >>sys.stderr, 'Title is not "LJCO weather and water sampling"'

    dateStart = datetime.datetime.strptime(netcdfFileObj.time_coverage_start, "%Y-%m-%dT%H:%M:%SZ")
    year      = dateStart.strftime('%Y')

    netcdfFilename     = removeCreationDateFromFilename(os.path.basename(netcdfFilePath))
    relativeNetcdfPath = os.path.join('SRS', 'OC', 'LJCO-WWS', year, netcdfFilename)

    netcdfFileObj.close()
    return relativeNetcdfPath

if __name__== '__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    destination_path = createFileHierarchy(sys.argv[1])

    if not destination_path:
        exit(1)

    print destination_path
    exit(0)
