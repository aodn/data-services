#! /usr/bin/env python
#
# Return the correct path for an ANMN Acidification Moorings NetCDF
# file within the opendap filesystem


import os
import sys
from netCDF4 import Dataset


def destPath(ncFile):
    """
    Return the correct location within the opendap filesystem the
    given netCDF file should be published to, based on the name
    and content of the file.

    Only works for ANMN Acidification Moorings files.

    """

    # Check that the file is indeed from ANMN-AM sub-facility
    fileName = os.path.basename(ncFile)  # just the filename, no path
    if ncFile.find('ANMN-AM') < 0:
        print >>sys.stderr, 'File %s is not an Acidification Moorings file!' % ncFile
        return None

    # open the file
    try:
        F = Dataset(ncFile, mode='r')
    except:
        print >>sys.stderr, 'Failed to open NetCDF file %s!' % ncFile
        return None

    # Start with base path for this sub-facility
    dirs = ['ANMN', 'AM']

    # add site code
    site_code = getattr (F, 'site_code', '')
    F.close()
    if not site_code:
        print >>sys.stderr, 'File %s has no site_code attribute!' % ncFile
        return None
    dirs.append(site_code)

    # add product sub-directory
    dirs.append('CO2')

    # add real-time/delayed
    if ncFile.find('delayed') > 0:
        dirs.append('delayed')
    elif ncFile.find('realtime') > 0:
        dirs.append('real-time')
    else:
        print >>sys.stderr, 'File %s is neither real-time nor delayed mode!' % ncFile
        return None

    return os.path.join(*dirs)


if __name__=='__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    answer = destPath(sys.argv[1])

    if not answer:
        exit(1)

    print answer
    exit(0)
