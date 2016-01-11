#! /usr/bin/env python

"""
Return the path / object id to publish an ANMN NetCDF file.

Input:
  incoming netCDF file

Output:
  relative path where file should go, including filename
  e.g. IMOS/ANMN/NRS/NRSMAI/Biogeochem_profiles/original_file_name.nc

Assume: (will be checked by handler)
 * File is netCDF
 * File was produced by the Toolbox
 * Site code has been validated in checker (if exists)
"""

import os
import sys
import re
from file_classifier import FileClassifier, FileClassifierException


class ANMNFileClassifier(FileClassifier):

    PROJECT = 'IMOS'
    FACILITY = 'ANMN'
    SUBFACS = ('NRS', 'NSW', 'SA', 'WA', 'QLD')


    @classmethod
    def _get_subfacility(cls, input_file):
        """Return the sub-facility the input_file belongs to."""
        pattern = '^IMOS_%s-([A-Z]+)_' % cls.FACILITY
        match = re.findall(pattern, os.path.basename(input_file))
        if not match:
            cls._error("Could not extract sub-facility from file name '%s'" % input_file)
        subfacility = match[0]
        if subfacility not in cls.SUBFACS:
            cls._error("Invalid sub-facility for ANMN '%s'" % subfacility)
        return subfacility


    @classmethod
    def _get_variable_names(cls, input_file):
        """Return a list of the variable names in the file."""
        dataset = cls._open_nc_file(input_file)
        names = dataset.variables.keys()
        dataset.close()
        return names


    @classmethod
    def _get_data_category(cls, input_file):
        """Determine the category a file belongs to (Temperature,
        CTD_timeseires, Biogeochem_profile, etc..)

        """

        feature_type = cls._get_nc_att(input_file, 'featureType')
        if feature_type == 'profile':
            return 'Biogeochem_profiles'

        var_names = set(cls._get_variable_names(input_file))
        salinity = set(['PSAL', 'CNDC'])
        bgc = set(['CPHL', 'CHLF', 'CHLU', 'FLU2', 'TURB', 'DOX1', 'DOX1_1', 'DOX2', 'DOXY', 'DOXS'])
        velocity = set(['UCUR', 'VCUR', 'WCUR'])
        wave = set(['VAVH', 'SSDS', 'SSDS_MAG', 'SSWD', 'SSWD_MAG', 'SSWDT', 'SSWST', 'SSWV',
                    'SSWV_MAG','SSWVT', 'VAVT', 'VDEN', 'VDEV', 'VDEP', 'VDES', 'VDIR', 'VDIR_MAG',
                    'VDIRT', 'WHTE', 'WHTH', 'WPFM', 'WPMH', 'WPSM', 'WPTE', 'WPTH', 'WMPP', 'WMSH',
                    'WMXH', 'WPDI', 'WPDI_MAG', 'WPDIT', 'WPPE', 'WSMP', 'WSSH']
        )

        if var_names.intersection(velocity):
            return 'Velocity'

        if var_names.intersection(wave):
            return 'Wave'

        if var_names.intersection(bgc):
            return 'Biogeochem_timeseries'

        if var_names.intersection(salinity):
            return 'CTD_timeseries'

        if 'TEMP' in var_names:
            return 'Temperature'

        cls._error("Could not determine data category for '%s'" % input_file)


    @classmethod
    def _get_file_name_fields(cls, input_file):
        """Return the '_'-separated fields in the file name as a list."""
        just_the_name = re.sub('\.nc$', '', os.path.basename(input_file))
        fields = just_the_name.split('_')
        return fields


    @classmethod
    def _get_product_level(cls, input_file):
        """Determine the product level of the file, i.e. either 'non-QC' (FV00), 'burst-averaged'
        or 'gridded' (FV02 products), or empty for FV01 files.

        """
        name_field = cls._get_file_name_fields(input_file)

        if name_field[5] == 'FV00':
            return 'non-QC'

        if name_field[5] == 'FV02':
            if len(name_field) < 7:
                cls._error("Can't determine product type from file name '%s'" % input_file)
            if 'burst-averaged' in name_field[6]:
                return 'burst-averaged'
            if 'gridded' in name_field[6]:
                return 'gridded'

        return ''


    @classmethod
    def dest_path(cls, input_file):
        """
        Destination (relative) path for an ANMN netCDF file.
        The path is 'IMOS/ANMN/<subfacility>/<site_code>/<data_category>/<product_level>'
        where <product_level> is
         - 'non-QC' for FV00 files
         - empty for FV01 files
         - 'burst-averaged' or 'gridded' as appropriate, for FV02 files
        The basename of the input file is appended.

        """
        dir_list = [cls.PROJECT, cls.FACILITY]
        dir_list.append(cls._get_subfacility(input_file))
        dir_list.append(cls._get_site_code(input_file))
        dir_list.append(cls._get_data_category(input_file))
        dir_list.append(cls._get_product_level(input_file))
        dir_list.append(os.path.basename(input_file))

        return cls._make_path(dir_list)


if __name__=='__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    input_path = sys.argv[1]

    try:
        dest_path = ANMNFileClassifier.dest_path(input_path)
    except FileClassifierException, e:
        print >>sys.stderr, e
        exit(1)

    print dest_path
    exit(0)
