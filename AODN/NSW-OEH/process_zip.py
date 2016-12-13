#! /usr/bin/env python

"""
Check the contents of a zip file containing NSW OEH data products.
If contents meet the required conventions, extract them to a given
temporary directory, listing each file extracted to stderr. Print
the S3 destination path for the files to stdout. Exit status 0.

If there are any problems with the zip file, print an error report
to stderr and exit with status 1.
"""

# TODO: unit tests


from __future__ import print_function

import sys
import os
import re
from datetime import datetime
import argparse
from collections import OrderedDict
import zipfile
import shutil


accepted_crs = ('W84Z55', 'W84Z56')
vertical_crs = dict(BTY='AHD', BKS='GRY')
shapefile_extensions = ('CPG', 'cpg', 'dbf', 'prj', 'sbn', 'sbx', 'shp', 'shp.xml', 'shx')
all_extensisons = ('xyz', 'xya', 'tif', 'tiff', 'sd', 'kmz', 'pdf') + shapefile_extensions
software_codes = ('FLD', 'FMG', 'ARC', 'GTX', 'GSP', 'HYP')
software_pattern = '(' + '|'.join(software_codes) + ')(\d{3})$'
file_versions = ('FV00', 'FV01', 'FV02')


def is_date(field):
    """Return true if field is a valid date in the format YYYYMMDD, false otherwise."""
    try:
        datetime.strptime(field, '%Y%m%d')
    except ValueError:
        return False

    return len(field) == 8


def check_crs(crs_field):
    """
    Check the coordinate reference system specified in the given
    field within a file name. Return an empty list or a list with
    a single message.

    """
    message = []
    if crs_field not in accepted_crs:
        message.append("Coordinate system should be one of {}.".format(accepted_crs))
    return message


def get_name_fields(path):
    """
    Return a tuple consisting of
    1) a list of uncerscore-separated fields in the file name, and
    2) the file name extension (part of name after the first '.')

    """
    file_name = os.path.basename(path)
    name, extension = file_name.split('.', 1)
    fields = name.split('_')
    return fields, extension


def get_survey_name(path):
    """
    Return the survey name (date and location) from the file name,
    or an empty string if file name is incorrect.
    """
    file_name = os.path.basename(path)
    m = re.match("NSWOEH_(\d{8}_[A-Za-z]+)", file_name)
    if m:
        return m.groups()[0]
    else:
        return ''


def check_name(file_name):
    """
    Check file_name against the NSW OEH naming convention. If the name
    does not meet the conventions, a list of messages detailing the
    errors is returned. An empty list indicates perfect compliance.

    """
    messages = []

    fields, extension = get_name_fields(file_name)
    if extension not in all_extensisons:
        messages.append("Unknown extension '{}'".format(extension))
    if len(fields) < 4:
        messages.append("File name should have at least 4 underscore-separated fields.")
        return messages

    # check organisation (NSWOEH) field
    if fields[0] != 'NSWOEH':
        messages.append("File name must start with 'NSWOEH'")

    # check date field
    if not is_date(fields[1]):
        messages.append("Field 2 should be a valid date (YYYYMMDD).")

    # check survey location field
    if len(fields) < 3 or not re.match("[A-Za-z]+$", fields[2]):
        messages.append("Field 3 should be a location code consisting only of letters.")

    # check survey methods field
    if fields[3] != 'MB':
        messages.append("Field 4 should be a valid survey method code (currently only 'MB' accepted)")

    # only 4 fields required for zip file name
    if extension == 'zip':
        return messages

    # check the product type and details field
    if len(fields) < 5:
        messages.append("File name should have at least 5 underscore-separated fields.")
        return messages

    # Determine file type from 5th field
    m = re.match("BTY|BKS|SHP$|ScientificRigour$", fields[4])
    if not m:
        messages.append("Unknown product type '{}'".format(fields[4]))
        return messages

    product_type = m.group()

    # Metadata document (PDF)
    if product_type == "ScientificRigour":
        if extension != "pdf":
            messages.append("The Scientific Rigour (metadata) sheet must be in PDF format.")
        return messages

    # Coverage shapefile
    if product_type == "SHP":
        if extension not in shapefile_extensions:
            messages.append("Unknown extension for shapefile '{}'".format(extension))
        return messages

    # KMZ file, no additional details needed
    if product_type in ('BKS', 'BTY') and extension == 'kmz':
        return messages

    # Bathymetry or backscatter data file
    if len(fields) < 9:
        messages.append(
            "Bathymetry & backscatter file names should have at least 9 underscore-separated fields."
        )

    if not re.match("(BTY|BKS)GRD\d{3}(GSS|R2S)", fields[4]):
        messages.append(
            "Field 5 contains unknown data product details " +
            "(expecting 'GRD', grid resolution in metres, system type GSS|R2S)."
        )

    if len(fields) < 6:
        return messages
    messages.extend(check_crs(fields[5][:6]))
    hhh = vertical_crs[product_type]
    if fields[5][6:] != hhh:
        messages.append(
            "For a '{}' product, field 6 should end with '{}'.".format(product_type, hhh)
        )

    # check 7th field (software and version)
    if len(fields) < 7:
        return messages
    if not re.match(software_pattern, fields[6]):
        messages.append(
            "Field 7 should be a valid software code {} "
            "followed by a 3-digit version number.".format(software_codes)
        )

    # check 8th field (product export date)
    if len(fields) < 8:
        return messages
    if not is_date(fields[7]):
        messages.append("Field 8 should be a valid date (YYYYMMDD).")

    # check 9th field file version
    if len(fields) < 9:
        return messages
    if fields[8] not in file_versions:
        messages.append("Field 9 should be a file version number {}".format(file_versions))

    return messages


def check_zip_contents(zip_file_path):
    """
    Check the contents of the zip file for consistency, presence of required files
    and compliance with conventions.

    :param str zip_file_path: path of zip file
    :return: error messages organised by heading
    :rtype: OrderedDict

    """
    # dict to contain all error messages
    report = OrderedDict()

    # open zip file and read content list
    if not zipfile.is_zipfile(zip_file_path):
        report[zip_file_path] = ["Not a valid zip archive!"]
        return report
    with zipfile.ZipFile(zip_file_path) as zf:
        path_list = zf.namelist()

    # Check each individual file name
    survey_names = []
    extensions = []
    for path in path_list:
        file_name = os.path.basename(path)
        if not file_name:
            continue  # skip directories

        _, ext = get_name_fields(file_name)
        extensions.append(ext)

        messages = check_name(file_name)
        sn = get_survey_name(file_name)
        if not sn:
            messages.append("Could not extract survey name from file name")
        survey_names.append(sn)
        if messages:
            report[file_name] = messages

    # TODO: check shapefile contents

    # Overall checks...
    messages = []
    # all files in zip should be for same survey (location & date)
    unique_surveys = set(survey_names)
    if len(unique_surveys) > 1:
        messages.append("Not all files are for the same survey "
                        "(survey names: {})".format(unique_surveys))

    # metadata sheet (PDF) exists
    if 'pdf' not in extensions:
        messages.append("Missing metadata file (PDF format)")

    # shapefile exists
    if 'shp' not in extensions:
        messages.append("Missing survey coverage shapefile")

    # at least one XYZ file
    if 'xyz' not in extensions:
        messages.append("Missing bathymetry xyz file")

    if messages:
        report["Zip file contents"] = messages

    return report


def get_dest_path(file_name):
    """
    Return the relative path the given multi-beam data file should be
    published to on S3. Or None if survey name can't be extracted.

    """
    survey_name = get_survey_name(file_name)
    if not survey_name:
        return None
    survey_year = survey_name[:4]
    return os.path.join('NSW-OEH', 'Multi-beam', survey_year, survey_name)


if __name__ == "__main__":
    # parse command line
    parser = argparse.ArgumentParser()
    parser.add_argument('zip_file', help="Full path to zip file")
    parser.add_argument('tmp_dir', help="Temporary directory to extract into")
    args = parser.parse_args()
    zip_file = args.zip_file
    tmp_dir = args.tmp_dir

    # TODO: check zip file name and get survey name

    # check contents
    report = check_zip_contents(zip_file)

    # if any errors, print details and exit with fail status
    if len(report) > 0:
        for heading, messages in report.iteritems():
            print("\n", heading, sep="", end="", file=sys.stderr)
            print("", *messages, sep="\n* ", file=sys.stderr)
        exit(1)

    # print dest path to stdout
    print(get_dest_path(zip_file))

    # if no errors, extract contents to temp directory and print list of files
    with zipfile.ZipFile(zip_file) as zf:
        for zip_name in zf.namelist():
            file_name = os.path.basename(zip_name)
            # skip directories
            if not file_name:
                continue

            try:
                ext_name = zf.extract(zip_name, tmp_dir)
            except:
                print("Failed to extract {} from {}".format(file_name, zip_file),
                      file=sys.stderr)
                exit(1)

            # Move file directly into base of tmp_dir, out of any directories in the zip file
            if zip_name != file_name:
                shutil.move(ext_name, tmp_dir)
            print(file_name, file=sys.stderr)

    exit(0)
