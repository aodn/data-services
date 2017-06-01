#!/usr/bin/env python
# -*- coding: utf-8 -*-
import os, sys
from netCDF4 import Dataset

def platform():
    return {
        'SG'     : 'seaglider',
        'SL'     : 'slocum_glider'
    }

def get_file_parts(ncFile):
    return os.path.basename(ncFile).split("_")

def get_facility(ncFile):
    return get_file_parts(ncFile)[1]

def get_code(ncFile):
    return get_file_parts(ncFile)[4][:2]

def get_platform(ncFile):
    code = get_code(ncFile)

    if code in platform():
        return platform()[code]
    else:
        print >>sys.stderr, "Error parsing platform code from '%s' " % ncFile
        exit(1)

def open_dataset(ncFile, mode):
    try:
        return Dataset(ncFile, mode=mode)
    except:
        print >>sys.stderr, "Failed to open NetCDF file '%s', mode '%s'" % ncFile, mode
        exit(1)


def get_deployment_id(ncFile):
    F = open_dataset(ncFile, 'r')
    title = getattr (F, 'title', '')
    F.close()
    deployment_id = title.split ()[-1]

    if ( deployment_id == 'mission'):
        print >>sys.stderr, "Missing deployment ID in '%s' " % ncFile
        return None
    else:
        return deployment_id


def dest_path(ncFile):
    """
    # eg :  IMOS_ANFOG_BCEOPSTUV_20150611T221605Z_SG153_FV01_timeseries_END-20150612T033529Z.nc
    # IMOS_<Facility-Code>_<Data-Code>_<Start-date>_<Platform-Code>_FV<File-Version>_*.nc
    """

    if len(get_file_parts(ncFile)) < 6:
        print >>sys.stderr, "File '%s' does not have enough parts" % ncFile
        return None


    print os.path.join(
        "ANFOG",
        "REALTIME",
        get_platform(ncFile),
        get_deployment_id(ncFile)
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
