#!/usr/bin/env python
# Returns the relative path to create for a modified SOOP TRV created by SOOP-TRV.py
#
# author Laurent Besnard, laurent.besnard@utas.edu.au
# lat mod: 19/11/2015

import datetime
import os, sys
from netCDF4 import Dataset
import re


def getMainSoopTrvVar(netcdfFilePath):
    netcdfFileObj = Dataset(netcdfFilePath,  mode='r')
    variables     = netcdfFileObj.variables.keys()
    netcdfFileObj.close()

    if   'CPHL' in variables:
        return 'CPHL'
    elif 'TEMP' in variables:
        return 'TEMP'
    elif 'PSAL' in variables:
        return 'PSAL'
    elif 'TURB' in variables:
        return 'TURB'

def getMainVarFolderName(netcdfFilePath):
    mainVar = getMainSoopTrvVar(netcdfFilePath)

    if   mainVar == 'CPHL':
        return 'chlorophyll'
    elif mainVar == 'TEMP':
        return 'temperature'
    elif mainVar == 'PSAL':
        return 'salinity'
    elif mainVar == 'TURB':
        return 'turbidity'

#netcdfFilePath='IMOS_SOOP-TRV_T_20151118T141237Z_VNCF_FV01_END-20151119T025006Z_C-20151119T190251Z.nc'
def removeCreationDateFromFilename(netcdfFilename):
    return re.sub('_C-.*$','.nc', netcdfFilename)

def createFileHierarchy(netcdfFilePath):
    netcdfFileObj = Dataset(netcdfFilePath, mode='r')
    shipCode      = netcdfFileObj.platform_code
    vesselName    = netcdfFileObj.vessel_name
    file_version  = netcdfFileObj.file_version
    mainVarFolder = getMainVarFolderName(netcdfFilePath)

    if file_version == "Level 0 - Raw data":
        levelName = 'noQAQC'
    elif file_version == 'Level 1 - Quality Controlled Data':
        levelName = 'QAQC'

    dateStart = datetime.datetime.strptime(netcdfFileObj.time_coverage_start, "%Y-%m-%dT%H:%M:%SZ")
    dateStart = dateStart.strftime('%Y%m%dT%H%M%SZ')
    dateEnd   = datetime.datetime.strptime(netcdfFileObj.time_coverage_end, "%Y-%m-%dT%H:%M:%SZ")
    dateEnd   = dateEnd.strftime('%Y%m%dT%H%M%SZ')

    netcdfFilename     = removeCreationDateFromFilename(os.path.basename(netcdfFilePath))
    relativeNetcdfPath = os.path.join('SOOP', 'SOOP-TRV', shipCode +  '_' + vesselName, 'By_Cruise','Cruise_START-'+ dateStart + '_END-' + dateEnd, mainVarFolder, netcdfFilename)

    netcdfFileObj.close()
    return relativeNetcdfPath

if __name__== '__main__':
    exit(1)

    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    destination_path = createFileHierarchy(sys.argv[1])

    if not destination_path:
        exit(1)

    print destination_path
    exit(0)
