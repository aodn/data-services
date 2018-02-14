#!/usr/bin/env python2
# -*- coding: utf-8 -*-
"""
create plots between old product if exists and new one.

Author: laurent.besnard@utas.edu.au
"""

import argparse
import os
import sys

import numpy as np
import pandas as pd
import pylab as pl
from matplotlib import gridspec
from netCDF4 import Dataset

from util import download_list_urls, get_s3_bucket_prefix


def plot_abs_comparison_old_new_product(old_product_rel_path, new_nc_path):
    
    tmp_old_prod_path = download_list_urls([os.path.join(get_s3_bucket_prefix(), old_product_rel_path)], "")
    old_nc_path = os.path.join(tmp_old_prod_path, os.path.basename(old_product_rel_path))

    nc_old_obj = Dataset(old_nc_path, 'r')
    nc_new_obj = Dataset(new_nc_path, 'r')

    d_index_eq = []
    for d_value in nc_new_obj['DEPTH']:
        d_index_eq.append(find_closest(nc_old_obj['DEPTH'][:], d_value))

    t_index_eq = (find_closest(nc_old_obj['TIME'][:], nc_new_obj['TIME'][0]))

    diff_mean_temp_per_depth = []
    for idx, d in enumerate(d_index_eq):
        diff_mean_temp_per_depth.append(np.nanmean(nc_new_obj['TEMP'][:, idx]) - np.nanmean(nc_old_obj['TEMP'][:, d]))

    if len(nc_old_obj['TEMP'][t_index_eq:]) == len(nc_new_obj['TEMP']) :
        df = (nc_new_obj['TEMP'][:, :] - nc_old_obj['TEMP'][t_index_eq:, d_index_eq, 0, 0])
    elif len(nc_old_obj['TEMP'][t_index_eq:]) < len(nc_new_obj['TEMP']):
        max_len = len(nc_old_obj['TEMP'][t_index_eq:])
        df = (nc_new_obj['TEMP'][:max_len, :] - nc_old_obj['TEMP'][t_index_eq:, d_index_eq, 0, 0])
    elif len(nc_old_obj['TEMP'][t_index_eq:]) > len(nc_new_obj['TEMP']):
        max_len = len(nc_new_obj['TEMP'][t_index_eq:])
        df = (nc_new_obj['TEMP'][:max_len, :] - nc_old_obj['TEMP'][:max_len, d_index_eq, 0, 0])

    df = pd.DataFrame(df)
    df = df.transpose()

    x = df.columns.values
    y = nc_new_obj['DEPTH'][:]
    Z = df.values

    fig = pl.figure(figsize=(30, 30))
    gs  = gridspec.GridSpec(5, 5)

    # ax1
    ax1 = fig.add_subplot(gs[:, 0:4])
    pcm = ax1.contourf(x, y, Z, 50, vmin=-np.nanmax(Z), cmap=pl.cm.RdBu_r)
    fig.gca().invert_yaxis()
    fig.colorbar(pcm, ax=ax1, extend='both', orientation='vertical')
    ax1.set_ylabel('Depth in meters')
    ax1.set_xlabel('Time grid index')
    ax1.set_title('Temp diff per grid cell between old and new prod')

    # ax2
    ax2 = fig.add_subplot(gs[:, 4], sharey=ax1)
    ax2.set_xlabel('Temp diff in Celsius')
    ax2.plot(diff_mean_temp_per_depth, y)
    ax2.set_title('mean diff of temperature per depth level between old and new prod')

    product_version_comparison_path = os.path.splitext(new_nc_path)[0] + '.png'
    pl.savefig(product_version_comparison_path)
    nc_old_obj.close()
    nc_new_obj.close()
    
    return product_version_comparison_path
    
def find_closest(A, target):
    #A must be sorted
    idx    = A.searchsorted(target)
    idx    = np.clip(idx, 1, len(A)-1)
    left   = A[idx-1]
    right  = A[idx]
    idx   -= target - left < right - target
    return idx

def args():
    parser = argparse.ArgumentParser(description='Creates comparison plot between existing FV02 ANMN temperature gridded product on S3 a new one created locally.\n Returns the path of the new locally generated comparison plot.')
    parser.add_argument('-n', "--new-local-fv02-file-full-path", dest='fv02_nc_path', type=str, help="full path to newly created FV02 ANMN temperature gridded product", required=True)
    parser.add_argument('-o', "--old-s3-fv02-file-relative-path", dest='previous_fv02_url', type=str, help="relative path on s3 starting from "+get_s3_bucket_prefix()+" to existing FV02 ANMN temperature gridded product.", required=True)
    vargs = parser.parse_args()

    if not os.path.isfile(vargs.fv02_nc_path):
        print('%s not a valid file' % vargs.fv02_nc_path)
        sys.exit(1)

    return vargs

def main(fv02_nc_path, previous_fv02_url):

    if previous_fv02_url == '':
        print('no previous product available. comparison plot can not be created')
    else:
        product_version_comparison_path = plot_abs_comparison_old_new_product(previous_fv02_url, fv02_nc_path)

    return product_version_comparison_path


if __name__ == "__main__":
    """ examples
    ./plot_abs_comparison_old_new_product.py IMOS/ANMN/NRS/NRSKAI/Temperature/gridded/IMOS_ANMN-NRS_Temperature_20120415T031500Z_NRSKAI_FV02_NRSKAI-1204-regridded_END-20121108T031500Z_C-20141211T043019Z.nc /tmp/tmpbvHlz_/IMOS_ANMN-NRS_T_20120415T030000Z_NRSKAI_FV02_NRSKAI-1204_gridded_END-20121108T030000Z.nc
    """
    vargs = args()
    product_version_comparison_path = main(vargs.fv02_nc_path, vargs.previous_fv02_url)
    print product_version_comparison_path
