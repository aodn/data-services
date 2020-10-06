#!/usr/bin/env python3
"""Rename ABOS files and attributes:

As part of the task of renaming ABOS files to DWM, this script identifies the attributes that contain the words
"ABOS" and "Bluewater" (as part of the Australian Bluewater Observing System), changes them for "DWM"/"Deep Water
Moorings" and rename the files. The attributes 'history' and 'toolbox_input_file' are excluded from the search as we
decided those attributes did not need to be changed. """

import warnings
import os
import netCDF4 as nc
import sys
import logging
from glob import glob


def find_att_with_str(ncobj: nc.Dataset, string: str = 'ABOS'):
    """ Search in the attributes which one has 'ABOS' in it, excluding the 'history' and 'toolbox_input_file'
    attributes (we do not need to change these) """
    attrs = []
    for attname in ncobj.ncattrs():
        attvalue = getattr(ncobj, attname)
        got_requested_string = type(attvalue) is str and string in attvalue
        if got_requested_string and attname != 'history' and attname != 'toolbox_input_file':
            attrs.append(attname)
    return attrs


def fix_abos_attributes(ncobj: nc.Dataset, namelist, old: str = 'ABOS', new: str = 'DWM'):
    """ Substitute 'ABOS' for 'DWM' in the attributes that contain 'ABOS' """
    for attname in namelist:
        attvalue = getattr(ncobj, attname)
        setattr(ncobj, attname, attvalue.replace(old, new))


def get_netcdf_files(folder: str):
    """ Get the nc files in the path given when calling the script in the command line """
    return glob(os.path.join(folder, '**/*.nc'), recursive=True)


def fix_abos_files(folder: str):
    """ Call the functions to replace attributes that contain 'ABOS' and/or 'Australia Bluewater Observing System') """
    files = get_netcdf_files(folder)
    for file in files:
        ncobj = nc.Dataset(file, 'a')
        abos_attributes = find_att_with_str(ncobj, 'ABOS')
        abos_blue_attributes = find_att_with_str(ncobj, 'Australia Bluewater Observing System')
        fix_abos_attributes(ncobj, abos_attributes, old='ABOS', new='DWM')
        fix_abos_attributes(ncobj, abos_blue_attributes, old='Australia Bluewater Observing System', new='Deep Water Moorings')
        for attr_name in abos_attributes:
            logging.info("New value for attribute '{name}': '{value}'".format(name=attr_name, value=getattr(ncobj, attr_name)))
        for attr_name in abos_blue_attributes:
            logging.info("New value for attribute '{name}': '{value}'".format(name=attr_name, value=getattr(ncobj, attr_name)))
        ncobj.close()
        rename_abos_file(file)


def rename_abos_file(old_filename: str):
    """ Rename the files substituting 'ABOS' for 'DWM' """
    if 'ABOS' not in old_filename:
        warnings.warn("Rename requested for: {}".format(old_filename))
        return
    else:
        new_filename = old_filename.replace("ABOS", "DWM")
        print("Renamed file: {}".format(new_filename))
        logging.info("Renamed file: {}".format(new_filename))
        os.rename(old_filename, new_filename)


if __name__ == '__main__':
    dataDIR = sys.argv[1]
    log_opts = {
        'format': '%(asctime)s %(message)s',
        'datefmt': '%m/%d/%Y %I:%M:%S %p',
        'level': logging.INFO,
        'filename': os.path.join(dataDIR, 'log_file_attrs_DWM.log')
    }
    logging.basicConfig(**log_opts)
    fix_abos_files(dataDIR)

