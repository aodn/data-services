#! /usr/bin/env python
#
# Find any previous versions of a given ANMN Acidification Moorings
# NetCDF file on the opendap filesystem.


import argparse
import os
import re
import sys

from netCDF4 import Dataset


def previousVersions(new_file, dest_path):
    """For an ANMN Acidification Moorings NetCDF file (ncFile) due to be
    published to destPath (given as a FULL PATH), find any previous
    versions of the file already there. Return a list of the full path
    of matching files.

    """

    matches = []

    # Extract product code from filename
    found = re.findall('(FV0\d_.*)_END', new_file)
    if len(found) != 1:
        print >>sys.stderr, 'Failed to find product code in filename %s!' % new_file
        return None
    product_code = found[0]

    # Read deployment_code from netCDF attributes
    try:
        D = Dataset(new_file)
    except:
        print >>sys.stderr, 'Failed to open NetCDF file %s!' % new_file
        return None
    deployment_code = getattr (D, 'deployment_code', '')
    D.close()
    if not deployment_code:
        print >>sys.stderr, 'File %s has no deployment_code attribute!' % new_file
        return None

    # Check that dest_path exists (if not yet, it obviously has no older versions)
    if not os.path.isdir(dest_path):
        print >>sys.stderr, 'Destination path %s does not exist!' % dest_path
        return []

    # Find files at destPath with name containing the product_code
    pattern = re.compile('.*%s.*\.nc' % product_code)
    for f in os.listdir(dest_path):
        if not pattern.match(f):
            continue
        old_file = os.path.join(dest_path, f)

        # For matching files, check that deployment_code attributes match
        # (issue warning if not!)
        try:
            D = Dataset(old_file)
        except:
            print >>sys.stderr, 'Failed to open NetCDF file %s!' % old_file
            continue
        if getattr (D, 'deployment_code', '') == deployment_code:
            matches.append(old_file)
        else:
            print >>sys.stderr, '%s has similar name to %s, but different deployment_code!' % (old_file, new_file)

    return matches


if __name__=='__main__':

    # get arguments from command-line
    parser = argparse.ArgumentParser()
    parser.add_argument('new_file', help='new ANMN-AM file')
    parser.add_argument('dest_path', help='full destination path')
    args = parser.parse_args()

    matches = previousVersions(args.new_file, args.dest_path)

    if matches is None:
        exit(1)

    for path in matches:
        print path

    exit(0)
