#! /usr/bin/env python

"""
Return the path / object id to publish an SOFS NetCDF file.

Input:
  incoming netCDF file

Output:
  object id of the file in S3 bucket storage

Assume: (will be checked by handler)
 * File is netCDF
 * Site code has been validated in checker (if exists)
"""

import os
import sys
import re
from datetime import datetime, timedelta

from file_classifier import FileClassifierException, MooringFileClassifier


class SOFSFileClassifier(MooringFileClassifier):
    WAVE_VAR = {'VAVH', 'HMAX', 'HAV'}
    MET_VAR = {'UWND', 'VWND', 'WDIR', 'WSPD', 'ATMP', 'AIRT', 'RELH', 'RAIN', 'RAIN_AMOUNT'}
    FLUX_VAR = {'H_RAIN', 'HEAT_NET', 'MASS_NET'}

    @classmethod
    def _get_data_category(cls, input_file):
        """Determine the category a file belongs to."""

        var_names = set(cls._get_variable_names(input_file))

        if re.search(r'\b(AZFP|AWCP)\b', cls._get_nc_att(input_file, 'instrument', ''), re.UNICODE):
            return 'Echo_sounder'

        if var_names.intersection(cls.WAVE_VAR):
            return 'Surface_waves'

        if var_names.intersection(cls.FLUX_VAR):
            return 'Surface_fluxes'

        if var_names.intersection(cls.MET_VAR):
            return 'Surface_properties'

        if var_names.intersection(cls.VELOCITY_VAR):
            return 'Sub-surface_currents'

        if var_names.intersection(cls.SALINITY_VAR) or var_names.intersection(cls.TEMP_VAR):
            return 'Sub-surface_temperature_pressure_conductivity'

        cls._error("Could not determine data category for '%s'" % input_file)

    @classmethod
    def _get_nc_att_date(cls, input_file, att_name, time_format='%Y-%m-%dT%H:%M:%SZ'):
        """Return the value of a timestamp global attribute as a datetime
        object. The default time format is as required by the IMOS conventions.

        """
        att_value = cls._get_nc_att(input_file, att_name)
        try:
            att_dt = datetime.strptime(att_value, time_format)
        except:
            cls._error("Could not parse attribute %s='%s' as a datetime (file '%s')" %
                       (att_name, att_value, input_file))
        return att_dt

    @classmethod
    def dest_path(cls, input_file):
        """
        Destination object path for an SOFS netCDF file.
        For delayed-mode files:
          'IMOS/ABOS/ASFS/SOFS/<data_category>'
        For real-time files:
          'IMOS/ABOS/ASFS/SOFS/<data_category>/Real-time/<year>_daily'

        The basename of the input file is appended.

        """

        dir_list = ['IMOS', 'ABOS', 'ASFS', 'SOFS']
        dir_list.append(cls._get_data_category(input_file))

        start_time = cls._get_nc_att_date(input_file, 'time_coverage_start')
        end_time = cls._get_nc_att_date(input_file, 'time_coverage_end')

        if end_time - start_time <= timedelta(days=1):
            # either real-time file or daily '1-min-avg' (delayed-mode) product
            if '1-min-avg' not in input_file:
                dir_list.append('Real-time')
            dir_list.append(start_time.strftime('%Y') + '_daily')

        dir_list.append(os.path.basename(input_file))

        return cls._make_path(dir_list)


if __name__ == '__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >> sys.stderr, 'No filename specified!'
        exit(1)

    input_path = sys.argv[1]

    try:
        dest_path = SOFSFileClassifier.dest_path(input_path)
    except FileClassifierException, e:
        print >> sys.stderr, e
        exit(1)

    print dest_path
    exit(0)
