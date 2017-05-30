#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys
import pdb
import re
from netCDF4 import Dataset

site_list = {
    'WAVEBAB': 'Batemans_Bay',
    'WAVEBYB': 'Byron_Bay',
    'WAVECOH': 'Coffs_Harbour',
    'WAVECRH': 'Crowdy_Head',
    'WAVEEDN': 'Eden',
    'WAVEPOK': 'Port_Kembla',
    'WAVESYD': 'Sydney'
}


def mhl_dest_path(nc_file):
    """
    #
    set destination path based on filename name
    eg : IMOS_ANMN-NSW_W_20150210T230000Z_WAVESYD_FV01_END-20151231T130000Z.nc
    """

    path_list = ['NSW-OEH', 'Manly_Hydraulics_Laboratory']
    nc_file_basename = os.path.basename(nc_file)
    site = nc_file_basename.split("_")[4]
    parameter = nc_file_basename.split("_")[2]

    if parameter == 'W':
        path_list.append('Wave')
    elif parameter == 'T':
        path_list.append('SST')
    else:
        print >>sys.stderr, ("File name doesn't match pattern for "
                             "any NSW-OEH MHL observation (%s)" % nc_file)
        return None

    # append the location of the site
    path_list.append(site_list[site])
    # append the filename
    path_list.append(nc_file_basename)

    return os.path.join(*path_list)


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)
    regex = 'IMOS_ANMN-NSW_[WT]_.*_WAVE[A-Z]{3}_.*.nc'
    if re.match(regex,sys.argv[1]):
        dest_path = mhl_dest_path(sys.argv[1])
    else:
       print >>sys.stderr, 'Invalid filename'
       exit(1)

    if not dest_path:
        exit(1)

    print dest_path
    exit(0)
