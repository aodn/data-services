#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys

from netCDF4 import Dataset

from ship_callsign import ship_callsign_list


def ships():
    return ship_callsign_list()

def getFileParts(ncFile):
    return os.path.basename(ncFile).split("_")

def getFacility(ncFile):
    return getFileParts(ncFile)[1]

def getCode(ncFile):
    return getFileParts(ncFile)[4]

def getCodeLong(ncFile):
    code = getCode(ncFile)

    if code in ships():
        return ships()[code]
    else:
        print >>sys.stderr, "Error parsing ship code from '%s' " % ncFile
        exit(1)

def getPlatform(ncFile):
    return getCode(ncFile) + "_" + getCodeLong(ncFile)

def openDataset(ncFile, mode):
    try:
        return Dataset(ncFile, mode=mode)
    except:
        print >>sys.stderr, "Failed to open NetCDF file '%s', mode '%s'" % ncFile, mode
        exit(1)

def getReportingId(ncFile):
    F = openDataset(ncFile, 'r')
    code = getCodeLong(ncFile);
    dateStart = getattr (F, 'time_coverage_start', '')
    dateEnd = getattr (F, 'time_coverage_end', '')
    F.close()

    if (not dateStart or not dateEnd):
        print >>sys.stderr, "Missing dateStart/dateEnd in '%s' " % ncFile
        return None

    try:
        return code + '_' + dateStart[:10].replace('-', '') + '-' + dateEnd[:10].replace('-', '')
    except:
        print >>sys.stderr, "Failed getting reporting_id from NetCDF file '%s'" % ncFile
        exit(1)

def addReportingId(ncFile):
    # to ensure consitency in the format of the data ID (voyage_id and deployemnt_id not always consistent),
    # add a reporting_id to the file : this is the variable to use for reporting from now on. HARVESTER HAS TO BE MODIFIED
    # reporting_id based on ship name, start and end date

    F = openDataset(ncFile, 'r+')
    reportingId = getReportingId(ncFile)
    F.reporting_id = str(reportingId)
    F.close()

    exit(0)


def destPath(ncFile):
    """
    # eg :   IMOS_SOOP-BA_AE_20110309T220303Z_WTEE_FV02_Oscar-Elton-Sette-38-120_END-20110324T172032Z_C-20141002T013852Z.nc
    # IMOS_<Facility-Code>_<Data-Code>_<Start-date>_<Platform-Code>_FV<File-Version>_vessel_name_*.nc
    """

    if len(getFileParts(ncFile)) < 6:
        print >>sys.stderr, "File '%s' does not have enough parts" % ncFile
        return None


    print os.path.join(
        "SOOP",
        getFacility(ncFile), # <Facility-Code>
        getPlatform(ncFile),
        getReportingId(ncFile)
    )

    exit(0)


if __name__ == '__main__':
    # read filename from command line
    if len(sys.argv) < 3:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    function = sys.argv[1]
    ncFile = sys.argv[2]

    globals()[function](ncFile)
