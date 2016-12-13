#! /usr/bin/env python

"""
Return the path / object id to publish an ANMN NetCDF file.

Input:
  incoming netCDF file

Output:
  relative path where file should go, including filename
  e.g. IMOS/ANMN/NRS/NRSMAI/Biogeochem_profiles/original_file_name.nc

Assume: (will be checked by handler)
 * File is netCDF, PDF or other allowed format
 * If NetCDF file, was produced by the Toolbox
 * Site code has been validated in checker (if exists)
"""

import os
import sys

from file_classifier import FileClassifierException, MooringFileClassifier


class NonNetCDFFileClassifier(MooringFileClassifier):

    @classmethod
    def _get_extension(cls, input_file):
        """Return the filename extension, if it exists, '' otherwise."""
        name_split = input_file.split('.')
        if len(name_split) > 1:
            return name_split[-1]
        else:
            return ''

    @classmethod
    def dest_path(cls, input_file):
        """
        Destination object path for files other than netCDF files. 
        Of the form:
          'IMOS/ANMN/<subfacility>/<site_code>/<data_category>/<input_file_basename>'
        where
        <data_category> is "Field_logsheets" for PDF files
                           "Biogeochem_profiles/non-QC/cnv" for .cnv files
                           "plots" for .png files
        """
        extension = cls._get_extension(input_file)
        name_fields = cls._get_file_name_fields(input_file)

        dir_list = [cls.PROJECT]
        dir_list.extend(cls._get_facility(input_file))

        if extension == 'pdf':
            dir_list.append(name_fields[3])  # site_code
            dir_list.append('Field_logsheets')
        elif extension == 'cnv':
            dir_list.append(name_fields[4])  # site_code
            dir_list.extend(['Biogeochem_profiles', 'non-QC', 'cnv'])
        elif extension == 'png':
            platform_code = name_fields[2]
            site_code = platform_code.split('-')[0]  # remove '-ADCP' etc.
            dir_list.append(site_code)
            dir_list.append('plots')
        else:
            cls._error("Don't know where to put file '%s' (unhandled extension)" % input_file)

        dir_list.append(os.path.basename(input_file))

        return cls._make_path(dir_list)
            


if __name__=='__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    input_path = sys.argv[1]

    if input_path.endswith('.nc'):
        classifier = MooringFileClassifier
    else:
        classifier = NonNetCDFFileClassifier

    try:
        dest_path = classifier.dest_path(input_path)
    except FileClassifierException, e:
        print >>sys.stderr, e
        exit(1)

    print dest_path
    exit(0)
