#! /usr/bin/env python

"""
Return the path / object id to publish an ABOS NetCDF file.

Input:
  incoming netCDF file

Output:
  object id of the file in S3 bucket storage

Assume: (will be checked by handler)
 * File is netCDF
 * File was produced by the Toolbox
 * Site code has been validated in checker (if exists)
"""

import os
import sys
import re

from datetime import timedelta

from file_classifier import FileClassifierException, MooringFileClassifier


class ABOSFileClassifier(MooringFileClassifier):

    @classmethod
    def _get_data_category(cls, input_file):
        """Determine the category a file belongs to (Temperature,
        CTD_timeseires, Velocity, etc..)

        """

        var_names = set(cls._get_variable_names(input_file))

        if var_names.intersection(cls.VELOCITY_VAR):
            return 'Velocity'

        if var_names.intersection(cls.BGC_VAR):
            return 'Biogeochem_timeseries'

        if var_names.intersection(cls.SALINITY_VAR):
            return 'CTD_timeseries'

        if var_names.intersection(cls.TEMP_VAR):
            return 'Temperature'

        cls._error("Could not determine data category for '%s'" % input_file)

    @classmethod
    def _get_product_level(cls, input_file):
        """Determine the product level of the file, i.e. either 'real-time', or
        'non-QC' (delayed-mode FV00). Otherwise empty.

        """
        name_field = cls._get_file_name_fields(input_file)

        if 'realtime' in input_file:
            return 'real-time'

        if name_field[5] == 'FV00':
            return 'non-QC'

        return ''

    @classmethod
    def _get_deployment_year(cls, input_file):
        """
        For the given moorings data file, determine the year in which the deployment started.
        If the time_deployment_start attribute is missing, fall back on time_coverage_start.

        :param str input_file: full path to the file
        :return: Year of deployment
        :rtype: str

        """
        start_date = cls._get_nc_att(input_file, 'time_deployment_start', time_format=True, default='')
        if not start_date:
            start_date = cls._get_nc_att(input_file, 'time_coverage_start', time_format=True)
        year = start_date.year

        return year

    @classmethod
    def _is_realtime(cls, input_file):
        """
        Determine whether the given file contains real-time data based on:
        * the data_mode global attribute, if it exists;
        * the file name, if it contains the word 'realtime' or 'real-time'
          (case insensitive);
        * the time_coverage_start/end range (if it's shorter than a day).

        :param str input_file: name of the file
        :return: Whether the input file contains real-time data
        :rtype bool

        """
        data_mode = cls._get_nc_att(input_file, 'data_mode', default='')
        if data_mode == 'R':
            return True
        # Any other valid data mode is NOT real-time
        if data_mode in ('P', 'D', 'M'):
            return False

        file_name = os.path.basename(input_file)
        if re.search(r'real-?time', file_name, re.IGNORECASE):
            return True

        time_start = cls._get_nc_att(input_file, 'time_coverage_start', time_format=True)
        time_end = cls._get_nc_att(input_file, 'time_coverage_end', time_format=True)
        if (time_end - time_start) <= timedelta(days=1):
            return True

        return False

    @classmethod
    def dest_path(cls, input_file):
        """
        Destination object path for an ABOS netCDF file. Of the form:

          'IMOS/ABOS/DA/<platform_code>/<data_category>/<product_level>'
          or
          'IMOS/ABOS/SOTS/<year_of_deployment>/<delivery_mode>'

        where 
        <platform_code> is the value of the platform_code global attribute
        <data_category> is a broad category like 'Temperature', 'CTD_profiles', etc...
        <product_level> is
         - 'non-QC' for FV00 files
         - empty for FV01 files
        <year_of_deployment> is the year in which the deployment started
        <delivery_mode> is either empty (for delayed mode data) or 'real-time'
        The basename of the input file is appended.

        """
        dir_list = [cls.PROJECT]

        (fac, subfac) = cls._get_facility(input_file)
        dir_list.append(fac)

        if subfac == 'DA':
            dir_list.append(subfac)
            dir_list.append(cls._get_nc_att(input_file, 'platform_code'))
            dir_list.append(cls._get_data_category(input_file))
            dir_list.append(cls._get_product_level(input_file))
        elif subfac in ('SOTS', 'ASFS'):
            dir_list.append('SOTS')
            dir_list.append(cls._get_deployment_year(input_file))
            if cls._is_realtime(input_file):
                dir_list.append('real-time')
        else:
            cls._error('Unknown ABOS sub-facility {sub}'.format(sub=subfac))

        dir_list.append(os.path.basename(input_file))

        return cls._make_path(dir_list)


if __name__ == '__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >> sys.stderr, 'No filename specified!'
        exit(1)

    input_path = sys.argv[1]

    try:
        dest_path = ABOSFileClassifier.dest_path(input_path)
    except FileClassifierException, e:
        print >> sys.stderr, e
        exit(1)

    print dest_path
    exit(0)
