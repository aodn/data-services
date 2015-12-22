#!/usr/bin/env python
# Returns the relative path to create for a SOOP XBT DM netcdf file
#
# author Laurent Besnard, laurent.besnard@utas.edu.au

import datetime
import os, sys
from netCDF4 import Dataset


def createFileHierarchy(netcdfFilePath):
    netcdfFileObj      = Dataset(netcdfFilePath, mode='r')
    xbtLine            = netcdfFileObj.XBT_line
    xbtLineDescription = netcdfFileObj.XBT_line_description

    dateStart          = datetime.datetime.strptime(netcdfFileObj.time_coverage_start, "%Y-%m-%dT%H:%M:%SZ")
    yearLine           = dateStart.strftime('%Y')
    relativeNetcdfPath = os.path.join('SOOP', 'SOOP-XBT', 'DELAYED', 'Line_' + xbtLine +'_' + xbtLineDescription, str(yearLine), os.path.basename(netcdfFilePath))

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
