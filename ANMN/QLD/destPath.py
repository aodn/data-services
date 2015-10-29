#! /usr/bin/env python
#
# Return the correct path for an ANMN QLD real-time NetCDF file within
# the opendap filesystem


import os
import sys
import re
from netCDF4 import Dataset


def destPath(ncFile):
    """Return the correct location within the opendap filesystem the given
    netCDF file should be published to, based on the name and content
    of the file. The returned path is relative to the base IMOS
    directory, and includes the name of the name of the file, with the
    end and creation timestamps removed.

    Only works for ANMN QLD real-time files.

    """

    # open the file
    try:
        F = Dataset(ncFile, mode='r')
    except:
        print >>sys.stderr, 'Failed to open NetCDF file %s!' % ncFile
        return None

    # Start with base path for this sub-facility
    path_list = ['ANMN', 'QLD']

    # add site code
    site_code = getattr (F, 'site_code', '')
    F.close()
    if not site_code:
        print >>sys.stderr, 'File %s has no site_code attribute!' % ncFile
        return None
    path_list.append(site_code)

    # add product sub-directory
    filename = os.path.basename(ncFile)
    if re.match('IMOS_ANMN-QLD_AETVZ_.*-ADCP', filename):
        path_list.append('Velocity')
    elif re.match('IMOS_ANMN-QLD_W_.*-wave', filename):
        path_list.append('Wave')
    elif re.match('IMOS_ANMN-QLD_CKOSTUZ_.*-WQM', filename):
        path_list.append('Biogeochem_timeseries')
    else:
        print >>sys.stderr, "File name doesn't match pattern for any known QLD real-time product (%s)" % filename
        return None

    # Real-time subdirectory
    path_list.append('real-time')

    # Remove end and creation date from filename and append it to the path
    dest_filename = re.sub('_(END|C)-\d{8}T\d{6}Z', '', filename)
    path_list.append(dest_filename)

    return os.path.join(*path_list)


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
