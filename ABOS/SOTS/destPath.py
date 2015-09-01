#! /usr/bin/env python
#
# Return the correct path for an ABOS SOTS NetCDF file within the
# opendap filesystem


import os
import sys
from netCDF4 import Dataset


def destPath(ncFile):
    """
    Return the correct location within the opendap filesystem the
    given netCDF file should be published to, based on the name
    and content of the file.

    Only works for ABOS SOTS moorings files.

    """

    # open the file
    try:
        F = Dataset(ncFile, mode='r')
    except:
        print >>sys.stderr, 'Failed to open NetCDF file %s!' % ncFile
        return None

    # Start with base path for this sub-facility
    dirs = ['ABOS', 'SOTS']

    # add platform code
    platform_code = getattr (F, 'platform_code', '')
    F.close()
    if not platform_code:
        print >>sys.stderr, 'File %s has no platform_code attribute!' % ncFile
        return None
    if platform_code.lower() != 'pulse':
        print >>sys.stderr, \
            "Don't know where to put file %s with platform_code '%s'!" % (ncFile, platform_code)
        return None
    dirs.append(platform_code)

    # Check if it's a real-time file
    if ncFile.find('realtime') > 0:
        dirs.append('real-time')

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
