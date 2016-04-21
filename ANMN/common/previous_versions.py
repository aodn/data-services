#! /usr/bin/env python
#
# Find any previous versions of an ANMN NetCDF file already at
# the destination path.


import os
import sys
import re
from glob import glob
from netCDF4 import Dataset
from datetime import datetime
import argparse
from file_classifier import MooringFileClassifier


class FileMatcherException(Exception):
    pass


class FileMatcher(MooringFileClassifier):
    """Identify previously published versions of a file."""

    @classmethod
    def _error(cls, message):
        "Raise an exception with the given message."
        raise FileMatcherException, message


    @classmethod
    def previous_versions(cls, new_file, dest_path):
        """For an ANMN NetCDF file due to be published to dest_path (given as
        a FULL PATH), find any previous versions of the file already
        there. Raise an exception if any such files appear to be newer
        than the new_file.

        Return the full paths of all matching files as a list.

        """

        matches = []

        # Check that dest_path exists (if not yet, it obviously has no older versions)
        if not os.path.isdir(dest_path):
            print >>sys.stderr, \
                "Destination path '%s' for '%s' does not exist" % (dest_path, new_file)
            return []

        # list of attributes to check in matching files. date_created must be last!
        attribute_list = ['deployment_code', 'instrument_serial_number', 'date_created']

        # for T-gridded product enough to match deployment code
        if cls._get_product_level(new_file) == 'gridded':
            attribute_list = ['deployment_code', 'date_created']

        # for profiles, use site_code, cruise id and start time instead
        if cls._get_nc_att(new_file, 'featureType', '') == 'profile':
            attribute_list = ['site_code', 'cruise', 'time_coverage_start', 'date_created']

        # Read new file attributes
        new_file_attr = cls._get_nc_att(new_file, attribute_list)
        new_file_created = datetime.strptime(new_file_attr[-1], '%Y-%m-%dT%H:%M:%SZ')

        # Find files at dest_path with the same start year and FV0x in file name
        fields = cls._get_file_name_fields(new_file)
        pattern = os.path.join(dest_path, '*_%s*_%s_*.nc'  % (fields[3][:4], fields[5]))
        prematches = glob(pattern)
        for old_file in prematches:

            # check if attributes match (except date_created)
            old_file_attr = cls._get_nc_att(old_file, attribute_list)
            old_file_created = datetime.strptime(old_file_attr[-1], '%Y-%m-%dT%H:%M:%SZ')
            if old_file_attr[:-1] == new_file_attr[:-1]:

                # check that new file is indeed newer
                if new_file_created < old_file_created:
                    cls._error("'%s' is not newer than previously published version '%s'" % \
                               (new_file, old_file))

                matches.append(old_file)

        return matches


if __name__=='__main__':

    # get arguments from command-line
    parser = argparse.ArgumentParser()
    parser.add_argument('new_file', help='new ANMN file')
    parser.add_argument('dest_path', help='full destination path')
    args = parser.parse_args()

    try:
        matches = FileMatcher.previous_versions(args.new_file, args.dest_path)
    except FileMatcherException, e:
        print >>sys.stderr, e
        exit(1)

    for path in matches:
        print path

    exit(0)
