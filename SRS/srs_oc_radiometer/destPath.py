#!/usr/bin/env python
# Returns the relative path of a SRS Radiometer Dalec netcdf file
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
    platformCode  = netcdfFileObj.platform_code
    fileVersion   = netcdfFileObj.file_version

    shipsDic = { 'VMQ9273' : 'Solander',
                 'VLHJ'    : 'Southern-Surveyor'}

    if  platformCode in shipsDic:
        vesselName = shipsDic[platformCode]
    else:
        print >>sys.stderr, 'Vessel name not known'

    if fileVersion == "Level 1 - calibrated radiance and irradiance data":
        fileVersionCode = 'FV01'
    elif fileVersion == "Level 0 - calibrated radiance and irradiance data":
        fileVersionCode = 'Fv00'
    else:
        print >>sys.stderr, 'file_version code is unknown - manual debug required'

    dateStart          = datetime.datetime.strptime(netcdfFileObj.time_coverage_start, "%Y-%m-%dT%H:%M:%SZ")
    dateEnd            = datetime.datetime.strptime(netcdfFileObj.time_coverage_end, "%Y-%m-%dT%H:%M:%SZ")
    year               = dateStart.strftime('%Y')

    netcdfFilename     = 'IMOS_SRS-OC_F_' + dateStart.strftime("%Y%m%dT%H%M%SZ") + '_' + platformCode + '_' + fileVersionCode + '_DALEC_END-' + dateEnd.strftime("%Y%m%dT%H%M%SZ") + '.nc'
    relativeNetcdfPath = os.path.join('SRS', 'OC', 'radiometer', platformCode +  '_' + vesselName, year, netcdfFilename)

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
