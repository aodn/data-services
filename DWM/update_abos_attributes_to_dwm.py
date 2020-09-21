#!/usr/bin/env python3
"""Rename ABOS files and attributes"""
# As part of the ABOS renaming Odyssey, this script identifies the attributes that contains the words "ABOS" and
# "Bluewater" (as art of the Australian Bluewater Observation System), changes them for "DWM"/"Deep Water Moorings"
# and rename the files. The attribute 'history' is excluded from the search as we decide that attribute did not need
# to be changed.


import warnings
import os
import netCDF4 as nc
import sys
from typing import List
from glob import glob


# search in the attributes which one has 'ABOS' in it, excluding the 'history' attribute (we do not need to change this)
def find_att_with_str(ncobj: nc.Dataset, string: str = 'ABOS'):
    attrs: List[str] = []
    for attname in ncobj.ncattrs():
        attvalue = getattr(ncobj, attname)
        got_requested_string = type(attvalue) is str and string in attvalue
        if got_requested_string and attname != 'history':
            attrs.append(attname)
    return attrs


# substitute 'ABOS' for 'DWM' in the attributes that contain 'ABOS'
def fix_abos_attributes(ncobj: nc.Dataset, namelist: List[str], old: str = 'ABOS', new: str = 'DWM'):
    for attname in namelist:
        attvalue = getattr(ncobj, attname)
        setattr(ncobj, attname, attvalue.replace(old, new))


# get the nc files in the path given when calling the script in the command line
def get_netcdf_files(folder: str):
    return glob(os.path.join(folder, '**/*.nc'), recursive=True)


# call the functions to replace attributes that contain 'ABOS' and/or 'Aus. Bluewater Obs. System') 
def fix_abos_files(folder: str):
    files = get_netcdf_files(folder)

    for file in files:
        ncobj = nc.Dataset(file, 'a')
        abos_attributes = find_att_with_str(ncobj, 'ABOS')
        abos_blue_attributes = find_att_with_str(ncobj, 'Australia Bluewater Observing System')
        fix_abos_attributes(ncobj, abos_attributes, old='ABOS', new='DWM')
        fix_abos_attributes(ncobj, abos_blue_attributes, old='Australia Bluewater Observing System',
                            new='Deep Water Moorings')
        ncobj.close()
        rename_abos_file(file)


# rename the files substituting 'ABOS' for 'DWM'
def rename_abos_file(old_filename: str):
    if 'ABOS' not in old_filename:
        warnings.warn(f"Rename requested for {old_filename}")
        return
    else:
        new_filename = old_filename.replace("ABOS", "DWM")
        print(f"Renaming {old_filename} -> {new_filename}")
        os.rename(old_filename, new_filename)


if __name__ == '__main__':
    dataDIR = sys.argv[1]
    fix_abos_files(dataDIR)
