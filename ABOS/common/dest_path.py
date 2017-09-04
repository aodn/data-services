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

from file_classifier import FileClassifierException, MooringFileClassifier


class ABOSFileClassifier(MooringFileClassifier):
    SEDIMENT_VAR = {'MASS_FLUX', 'CACO3', 'PIC', 'POC', 'BSIO2'}

    @classmethod
    def _get_data_category(cls, input_file):
        """Determine the category a file belongs to (Temperature,
        CTD_timeseires, Velocity, etc..)

        """

        var_names = set(cls._get_variable_names(input_file))

        if var_names.intersection(cls.SEDIMENT_VAR):
            return 'Sediment_traps'

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
    def dest_path(cls, input_file):
        """
        Destination object path for an ABOS netCDF file. Of the form:

          'IMOS/ABOS/<subfacility>/<platform_code>/<data_category>/<product_level>'

        where 
        <subfacility> is the sub-facility code ('DA, 'SOTS', 'ASFS')
        <platform_code> is the value of the platform_code global attribute
        <data_category> is a broad category like 'Temperature', 'CTD_profiles', etc...
        <product_level> is
         - 'non-QC' for FV00 files
         - empty for FV01 files
        The basename of the input file is appended.

        """

        (fac, subfac) = cls._get_facility(input_file)
        platform_code = cls._get_nc_att(input_file, 'platform_code')

        dir_list = [cls.PROJECT]
        dir_list.extend([fac, subfac])
        dir_list.append(platform_code)

        # no data categories for Pulse and FluxPulse moorings
        if platform_code not in ('Pulse', 'FluxPulse'):
            dir_list.append(cls._get_data_category(input_file))

        dir_list.append(cls._get_product_level(input_file))
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
