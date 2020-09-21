#!/usr/bin/env python3
"""Rename ABOS files and attributes"""

import warnings
import os
import netCDF4 as nc
from typing import List
from glob import glob


# def test_replace_abos_str():
#     string = 'my_test_XXX'
#     old = 'XXX'
#     new = 'YYY'
#     expected = 'my_test_YYY'
#     result = replace_abos_str(string, old, new)
#     assert(result == expected)

def find_att_with_str(ncobj: nc.Dataset, string: str = 'ABOS'):
    attrs: List[str] = []
    # for k,v in global_attr_dict:
    #    got_requested_string = type(v) is str and string in v
    #    if got_requested_string:
    #        attrs.append(k)

    for attname in ncobj.ncattrs():
        attvalue = getattr(ncobj, attname)
        got_requested_string = type(attvalue) is str and string in attvalue
        if got_requested_string:
            attrs.append(attname)
    return attrs


def replace_abos_str(string: str, old: str = 'ABOS', new: str = 'DWM'):
    return string.replace(old, new)


def fix_abos_attributes(ncobj: nc.Dataset, namelist: List[str], old: str = 'ABOS', new: str = 'DWM'):
    for attname in namelist:
        attvalue = getattr(ncobj, attname)
        new_attvalue = replace_abos_str(attvalue, old, new)
        setattr(ncobj, attname, new_attvalue)


def get_netcdf_files(folder: str):
    return glob(os.path.join(folder, '**/*.nc'), recursive=True)


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


def rename_abos_file(old_filename: str):
    if 'ABOS' not in old_filename:
        warnings.warn(f"Rename requested for {old_filename}")
        return
    else:
        new_filename = old_filename.replace("ABOS", "DWM")
        print(f"Renaming {old_filename} -> {new_filename}")
        os.rename(old_filename, new_filename)


if __name__ == '__main__':
    dataDIR1 = '/mnt/imos-test-data/IMOS/ABOS/'
    fix_abos_files(dataDIR1)
