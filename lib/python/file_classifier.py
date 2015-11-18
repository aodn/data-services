"""FileClassifier - Generic class for working out the destination path of
a file to be published. The idea is to define the common functionality
here, then create subclasses to customise for each specific incoming
handler. 

The dest_path implemented here consists of facility code, sub-facility
code, and site_code, which works well for moorings data. All
functionality can be overridden in sub-classes.

Expected use:

    class MyFileClassifier(FileClassifier):
        def dest_path(self, input_file):
            ...

    try:
        fs = MyFileClassifier()
        dest_path = fs.dest_path(input_file)
    except FileClassifierException:
        exit(1)

    print dest_path

"""

import os
import sys
import re
from netCDF4 import Dataset


class FileClassifierException(Exception):
    def __init__(self, message='Unknown error in FileClassifier'):
        Exception.__init__(self, message)
        print >>sys.stderr, message


class FileClassifier(object):
    "Base class for working out where a file should be published."

    def __init__(self, facility='', subfacility=''):
        self.facility = facility
        self.subfacility = subfacility

    def dest_path(self, input_file):
        """
        Return the destination path for file at input_file. 
        Returns "<facility>/<subfacility>/<site_code>"

        """
        dir_list = [self.facility]
        dir_list.append(self._get_subfacility())
        dir_list.append(self._get_site_code(input_file))
        return os.path.join(*dir_list)

    def _open_nc_file(self, file_path):
        "Open a NetCDF file for reading"
        try:
            return Dataset(file_path, mode='r')
        except:
            raise FileClassifierException, "Could not open NetCDF file '%s'." % file_path

    def _get_nc_att(self, file_path, att_name):
        "Return the value of a global attribute from a NetCDF file"
        dataset = self._open_nc_file(file_path)
        if not dataset:
            return None

        att = getattr(dataset, att_name, None)
        dataset.close()
        if not att:
            raise FileClassifierException, "File '%s' has no attribute '%s'" % (file_path, att_name)
        return att

    def _get_subfacility(self):
        return self.subfacility

    def _get_site_code(self, input_file):
        "Return the site_code attribute of the input_file"
        return self._get_nc_att(input_file, 'site_code')

