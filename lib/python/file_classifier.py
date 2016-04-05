"""FileClassifier - Generic class for working out the destination path of
a file to be published. The idea is to define the common functionality
here, then create subclasses to customise for each specific incoming
handler. 

Expected use:

    class MyFileClassifier(FileClassifier):
        def dest_path(self, input_file):
            path = <case-specific logic> 
            ...
            return path

    try:
        dest_path = MyFileClassifier.dest_path(input_file)
    except FileClassifierException, e:
        print >>sys.stderr, e
        exit(1)

    print dest_path

"""

import os
import sys
import re
from netCDF4 import Dataset


class FileClassifierException(Exception):
    pass


class FileClassifier(object):
    "Base class for working out where a file should be published."

    @classmethod
    def _error(cls, message):
        "Raise an exception with the given message."
        raise FileClassifierException, message


    @classmethod
    def _get_file_name_fields(cls, input_file, min_fields=6):
        """Return the '_'-separated fields in the file name as a list.
        Raise an exception if the number of fields is less than min_fields.
        """
        # trim off dirs & extention
        basename = os.path.basename(input_file)
        just_the_name = re.sub('\.\w*$', '', basename)

        fields = just_the_name.split('_')
        if len(fields) < min_fields:
            cls._error("'%s' has less than %d fields in file name." % (input_file, min_fields))
        return fields


    @classmethod
    def _get_facility(cls, input_file, check_sub=True):
        """Get the facility/sub-facility from the file name and return as a
        tuple ('facility', 'sub-facility'). Raise exception if no
        sub-facility is present, unless check_sub is False.

        """
        name_field = cls._get_file_name_fields(input_file, min_fields=2)
        fac_subfac = name_field[1].split('-')
        if check_sub and len(fac_subfac) < 2:
            cls._error("Missing sub-facility in file name '%s'" % input_file)
        return tuple(fac_subfac)


    @classmethod
    def _open_nc_file(cls, file_path):
        "Open a NetCDF file for reading"
        try:
            return Dataset(file_path, mode='r')
        except:
            cls._error("Could not open NetCDF file '%s'." % file_path)


    @classmethod
    def _get_nc_att(cls, file_path, att_name, default=None):
        """Return the value of a global attribute from a NetCDF file. If a
        list of attribute names is given, a list of values is
        returned.  Unless a default value other than None is given, a
        missing attribute raises an exception.

        """
        dataset = cls._open_nc_file(file_path)

        if isinstance(att_name, list):
            att_list = att_name
        else:
            att_list = [att_name]
        values = []

        for att in att_list:
            val = getattr(dataset, att, default)
            if val is None:
                cls._error("File '%s' has no attribute '%s'" % (file_path, att))
            values.append(val)
        dataset.close()

        if isinstance(att_name, list):
            return values
        return values[0]


    @classmethod
    def _get_site_code(cls, input_file):
        "Return the site_code attribute of the input_file"
        return cls._get_nc_att(input_file, 'site_code')


    @classmethod
    def _get_variable_names(cls, input_file):
        """Return a list of the variable names in the file."""
        dataset = cls._open_nc_file(input_file)
        names = dataset.variables.keys()
        dataset.close()
        return names


    @classmethod
    def _make_path(cls, dir_list):
        """Create a path from a list of directory names, making sure the
         result is a plain ascii string, not unicode (which could
         happen if some of the components of dir_list come from NetCDF
         file attributes).

        """
        for i in range(len(dir_list)):
            dir_list[i] = str(dir_list[i])
        return os.path.join(*dir_list)


class MooringFileClassifier(FileClassifier):

    PROJECT = 'IMOS'

    SALINITY_VAR = set(['PSAL', 'CNDC'])
    BGC_VAR = set(['CPHL', 'CHLF', 'CHLU', 'FLU2', 'TURB', 'DOX1', 'DOX1_1', 'DOX2', 'DOXY', 'DOXS'])
    VELOCITY_VAR = set(['UCUR', 'VCUR', 'WCUR'])
    WAVE_VAR = set(['VAVH', 'SSDS', 'SSDS_MAG', 'SSWD', 'SSWD_MAG', 'SSWDT', 'SSWST', 'SSWV',
                    'SSWV_MAG','SSWVT', 'VAVT', 'VDEN', 'VDEV', 'VDEP', 'VDES', 'VDIR', 'VDIR_MAG',
                    'VDIRT', 'WHTE', 'WHTH', 'WPFM', 'WPMH', 'WPSM', 'WPTE', 'WPTH', 'WMPP', 'WMSH',
                    'WMXH', 'WPDI', 'WPDI_MAG', 'WPDIT', 'WPPE', 'WSMP', 'WSSH']
    )
    TEMP_VAR = set(['PRES', 'PRES_REL', 'TEMP'])

    @classmethod
    def _get_data_category(cls, input_file):
        """Determine the category a file belongs to (Temperature,
        CTD_timeseires, Biogeochem_profile, etc..)

        """

        var_names = set(cls._get_variable_names(input_file))

        if var_names.intersection(cls.VELOCITY_VAR):
            return 'Velocity'

        if var_names.intersection(cls.WAVE_VAR):
            return 'Wave'

        feature_type = cls._get_nc_att(input_file, 'featureType').lower()
        if feature_type == 'profile':
            if var_names.intersection(cls.BGC_VAR) or var_names.intersection(cls.SALINITY_VAR):
                return 'Biogeochem_profiles'
            else:
                 cls._error("Could not determine data category for '%s'" % input_file)

        if feature_type == 'timeseries':
            if var_names.intersection(cls.BGC_VAR):
                return 'Biogeochem_timeseries'

            if var_names.intersection(cls.SALINITY_VAR):
                return 'CTD_timeseries'

        if var_names.intersection(cls.TEMP_VAR):
            return 'Temperature'

        cls._error("Could not determine data category for '%s'" % input_file)


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
        Destination object path for a moorings netCDF file. Of the form:

          'IMOS/<facility>/<subfacility>/<site_code>/<data_category>/<product_level>'

        where 
        <facility> = 'ANMN' or 'ABOS'
        <subfacility> is the sub-facility code ('NRS', 'NSW', 'SOTS', etc...)
        <site_code> is the value of the site_code global attribute
        <data_category> is a broad category like 'Temperature', 'CTD_profiles', etc...
        <product_level> is
         - 'non-QC' for FV00 files
         - empty for FV01 files
         - 'burst-averaged' or 'gridded' as appropriate, for FV02 files
        The basename of the input file is appended.

        """

        dir_list = [cls.PROJECT]
        dir_list.extend(cls._get_facility(input_file))
        dir_list.append(cls._get_site_code(input_file))
        dir_list.append(cls._get_data_category(input_file))
        dir_list.append(cls._get_product_level(input_file))
        dir_list.append(os.path.basename(input_file))

        return cls._make_path(dir_list)
