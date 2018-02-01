#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
This scripts aggregates Temperature logger data collected on the mooring line
during a deployment by binning and averaging them temporally, then by
interpolating temperature values vertically on a common grid.

The script takes as input argument either one FV01 file (and will query a WFS
layer to use also the data from the same deployment to create this product), or
as an alternative, the script can be run only with a deployment code string value

Please refer to ./anmn_temp_gridded_product.py -h for more description related to
inputs

The script will return path to the new FV02 product and the relative path of the
FV02 product already on the data storage if exists (which needs to be removed)
respectively

Author: laurent.besnard@utas.edu.au
"""


import argparse
import os
import re
import shutil
import sys
import tempfile
import urllib2
from datetime import datetime, timedelta

import numpy as np
import pandas as pd
import pylab as pl
from matplotlib import gridspec
from netCDF4 import Dataset, date2num, num2date

from generate_netcdf_att import generate_netcdf_att, get_imos_parameter_info
from imos_logging import IMOSLogging
from util import get_git_revision_script_url, wfs_request_matching_file_pattern


def plot_abs_comparison_old_new_product(old_product_rel_path, new_nc_path):
    """
    create optional plots between old product if exists and new one.
    """
    tmp_old_prod_path = download_list_nc([os.path.join(s3_bucket_prefix, old_product_rel_path)])
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

def get_var_var_qc_in_deployment(varname, nc_file_list):
    """
    Return the variable values and its qc flags for all netcdf files in list
    """
    var, var_qc = [], []
    for i, f in enumerate(nc_file_list):
        netcdf_file_obj = Dataset(f, 'r')

        if varname == 'TIME':
            time = netcdf_file_obj['%s' % varname]
            time = num2date(time[:], time.units, time.calendar)
            var.append(time)
        else:
            var.append(netcdf_file_obj['%s' % varname][:])

        # create a default qc array of 1 (values to keep) if QC var does no
        # exist
        if ('%s_quality_control' % varname) in netcdf_file_obj.variables.keys():
            var_qc.append(netcdf_file_obj['%s_quality_control' % varname][:])
        else:
            var_qc.append(np.ones(netcdf_file_obj['%s' % varname].shape[0]))
        netcdf_file_obj.close()

    return var, var_qc

def get_good_values(var, var_qc):
    """
    Return the variable values which qc flag is 0, 1 or 2
    """
    var = var[var_qc <= 2]
        
    return var

def get_data_in_deployment(nc_file_list):
    """
    return depth, time and temp data with flags <= 2 for all nc files
    """
    temp,  temp_qc  = get_var_var_qc_in_deployment('TEMP',  nc_file_list)
    depth, depth_qc = get_var_var_qc_in_deployment('DEPTH', nc_file_list)
    time,  time_qc  = get_var_var_qc_in_deployment('TIME',  nc_file_list)

    for ii in range(len(temp)):
        # we combine temp, depth and time QC information to only return data that has good temp, depth and time
        all_qc = np.maximum(temp_qc[ii], depth_qc[ii]) # element wise maximum of array element
        all_qc = np.maximum(all_qc, time_qc[ii])
    
        temp[ii]  = get_good_values(temp[ii],  all_qc)
        depth[ii] = get_good_values(depth[ii], all_qc)
        time[ii]  = get_good_values(time[ii],  all_qc)

    return temp, depth, time

def get_min_max_var_deployment(nc_file_list):
    """
    return the min and max values of temp, depth and time for a list of nc files
    """
    temp, depth, time = get_data_in_deployment(nc_file_list)
    
    max_temp,  min_temp  = [], []
    max_depth, min_depth = [], []
    max_time,  min_time  = [], []
    for ii in range(len(temp)):
        max_temp.append(np.max(temp[ii]))
        min_temp.append(np.min(temp[ii]))
        
        max_depth.append(np.max(depth[ii]))
        min_depth.append(np.min(depth[ii]))
        
        max_time.append(np.max(time[ii]))
        min_time.append(np.min(time[ii]))

    max_temp = max(max_temp)
    min_temp = min(min_temp)

    max_depth = max(max_depth)
    min_depth = min(min_depth)
    
    max_time = max(max_time)
    min_time = min(min_time)
    
    return min_temp, max_temp, min_depth, max_depth, min_time, max_time

def daterange(date1, date2, step_in_seconds):
    for n in range(int(round(((date2 - date1).total_seconds()/step_in_seconds))) + 1):
        yield date1 + timedelta(seconds=n*step_in_seconds)

def create_time_1d(time_start, time_end, delta_in_minutes):
    """
    create a 1D time array between start and end date and a data step of delta_in_minute
    we want this time array to be rounded to a resolution of delta_in_minute and 
    to possibly fall on the hour 00:00:00
    """
    time_interp_array = []
    
    time_start_msus = timedelta(minutes=time_start.minute, seconds=time_start.second, microseconds=time_start.microsecond)
    time_end_msus   = timedelta(minutes=time_end.minute,   seconds=time_end.second,   microseconds=time_end.microsecond)
    
    time_start_rounded = datetime(time_start.year, time_start.month, time_start.day, time_start.hour)
    time_end_rounded   = datetime(time_end.year,   time_end.month,   time_end.day,   time_end.hour)
    
    time_start_rounded = time_start_rounded + timedelta(seconds=np.round(time_start_msus.total_seconds()/(delta_in_minutes*60))*delta_in_minutes*60)
    time_end_rounded   = time_end_rounded   + timedelta(seconds=np.round(time_end_msus.total_seconds()  /(delta_in_minutes*60))*delta_in_minutes*60)
    
    for dt in daterange(time_start_rounded, time_end_rounded, delta_in_minutes*60):
        time_interp_array.append(dt)
    
    return time_interp_array

def create_monotonic_grid_array(nc_file_list):
    """
    create the interpolated depth and time array. The depth interpolation is 1 meter
    """
    min_temp, max_temp, min_depth, max_depth, time_start, time_end = get_min_max_var_deployment(nc_file_list)
    depth_1d_1meter = range(int(np.ceil(min_depth)), int(np.floor(max_depth)) + 1, 1)
    time_1d_interp  = create_time_1d(time_start, time_end, delta_in_minutes=60)

    return depth_1d_1meter, time_1d_interp

def find_closest(A, target):
    #A must be sorted
    idx    = A.searchsorted(target)
    idx    = np.clip(idx, 1, len(A)-1)
    left   = A[idx-1]
    right  = A[idx]
    idx   -= target - left < right - target
    return idx

def create_temp_interp_gridded(time_1d_interp, depth_1d_interp, temp_values, time_values, depth_values):
    """
    create the interpolated gridded temperature data. The reference grid is time_1d_interp,
    and depth_1d_interp.
    We first look for temp values within time bins, average them, and then do a
    linear interpolation over the depth
    """    
    # initialise with nan
    temp_gridded = np.array([[np.nan]*len(time_1d_interp) for _ in range(len(depth_1d_interp))])

    n_file = len(temp_values)
    n_time = len(time_1d_interp)
    
    temp_binned_array  = []
    depth_binned_array = []
    
    time_delta = (time_1d_interp[1]- time_1d_interp[0])
        
    time_bins_start = []
    for j in range(n_time):
        time_bins_start.append(time_1d_interp[j] - time_delta/2) # time_1d_interp sits in the centre of the bin

    time_bins_start.append(time_1d_interp[j] + time_delta/2) # add last value

    # histogram doesn't work with datetime so we need to use timestamps in seconds since a reference date
    to_timestamp = np.vectorize(lambda x: (x - datetime(1970, 1, 1)).total_seconds())
    
    timestamp_bins_start = to_timestamp(time_bins_start)
    
    # temporal binning per dataset
    for i_file in range(n_file):        
        timestamp_values = to_timestamp(time_values[i_file])
        
        time_hist = np.histogram(timestamp_values, timestamp_bins_start)[0] # sometimes there is no data in a bin -> 0
        
        temp_binned  = np.histogram(timestamp_values, timestamp_bins_start, weights=temp_values[i_file]) [0] / time_hist # when there is no data in a bin -> 0 divided by 0 yields a NaN
        depth_binned = np.histogram(timestamp_values, timestamp_bins_start, weights=depth_values[i_file])[0] / time_hist
        
        temp_binned_array.append(temp_binned)
        depth_binned_array.append(depth_binned)

    # vertical interpolation per time stamp
    for j in range(n_time):
        temp_binned  = np.array([row[j] for row in temp_binned_array])
        depth_binned = np.array([row[j] for row in depth_binned_array])
        
        temp_binned  = temp_binned [~np.isnan(temp_binned)]
        depth_binned = depth_binned[~np.isnan(depth_binned)]
        
        # we need to sort temp and depth by increasing depths before we can interpolate
        temp_binned = [x for _,x in sorted(zip(depth_binned,temp_binned))]
        depth_binned.sort()
        
        # we only want to interpolate what's between the depth_binned range, what is below or above is nan
        temp_gridded[:,j] = np.interp(depth_1d_interp, depth_binned, temp_binned, left=np.nan, right=np.nan)
    
    return temp_gridded

def list_instrument_nominal_depth(nc_file_list):
    """ return a list of nominal_depth gatt from the nc files"""
    instrument_nominal_depth = []
    for f in nc_file_list:
        netcdf_file_obj = Dataset(f, 'r')
        instrument_nominal_depth.append(netcdf_file_obj.instrument_nominal_depth)
        netcdf_file_obj.close()
    instrument_nominal_depth.sort()
    return instrument_nominal_depth

def generate_fv02_filename(time_1d_interp, nc_file_list):
    """ return the file name only of the FV02 product """
    netcdf_file_obj   = Dataset(nc_file_list[0], 'r')
    site_code         = netcdf_file_obj.site_code
    deployment_code   = netcdf_file_obj.deployment_code
    input_netcdf_name = os.path.basename(nc_file_list[0])
    pattern           = re.compile("^(IMOS_.*)_([A-Z].*)_([0-9]{8}T[0-9]{6}Z)_(.*)_FV01_(.*)_END")
    match_group       = pattern.match(input_netcdf_name)

    time_start  = min(time_1d_interp).strftime('%Y%m%dT%H%M%SZ')
    time_end    = max(time_1d_interp).strftime('%Y%m%dT%H%M%SZ')

    output_netcdf_name = '%s_T_%s_%s_FV02_%s_gridded_END-%s.nc' % (match_group.group(1), time_start,
                                                                    site_code, deployment_code, time_end)

    netcdf_file_obj.close()
    return output_netcdf_name

def generate_fv02_netcdf(temp_gridded, time_1d_interp, depth_1d_interp, nc_file_list):
    """ generated the FV02 temperature gridded product netcdf file """
    tmp_netcdf_dir          = tempfile.mkdtemp()
    output_netcdf_file_path = os.path.join(tmp_netcdf_dir, generate_fv02_filename(time_1d_interp, nc_file_list))

    input_netcdf_obj               = Dataset(nc_file_list[0], 'r')
    output_netcdf_obj              = Dataset(output_netcdf_file_path, "w", format="NETCDF4")
    output_netcdf_obj.date_created = datetime.now().strftime("%Y-%m-%dT%H:%M:%SZ")

    # read gatts from input, add them to output. Some gatts will be overwritten
    input_gatts     = input_netcdf_obj.__dict__.keys()
    gatt_to_dispose = ['author', 'toolbox_input_file', 'file_version', 'file_version_quality_control', 'quality_control_set',
                       'CoordSysBuilder_', 'date_created', 'netcdf_filename', 'metadata', 'instrument_serial_number',
                       'instrument_nominal_depth', 'compliance_checker_version', 'compliance_checker_last_updated',
                       'geospatial_vertical_min', 'geospatial_vertical_max', 'featureType',
                       'time_deployment_start_origin' , 'time_deployment_end_origin']


    for gatt in input_gatts:
        if gatt not in gatt_to_dispose:
            setattr(output_netcdf_obj, gatt, getattr(input_netcdf_obj, gatt))

    comment = 'comment: The following files have been used to generate the gridded product:\n%s' % " \n".join([os.path.basename(x) for x in nc_file_list])
    setattr(output_netcdf_obj, 'comment', comment)
    setattr(output_netcdf_obj, 'temporal_resolution', 60 )
    setattr(output_netcdf_obj, 'vertical_resolution', 1 )
    setattr(output_netcdf_obj, 'featureType', 'timeSeriesProfile' )

    instrument_nominal_depth = ", ".join(map(str, list_instrument_nominal_depth(nc_file_list)))
    setattr(output_netcdf_obj, 'instrument_nominal_depth', instrument_nominal_depth)

    output_netcdf_obj.createDimension("TIME", temp_gridded.shape[1])
    output_netcdf_obj.createDimension("DEPTH", temp_gridded.shape[0])
    output_netcdf_obj.createDimension("LATITUDE", 1)
    output_netcdf_obj.createDimension("LONGITUDE", 1)

    var_time     = output_netcdf_obj.createVariable("TIME", "d", "TIME", fill_value=get_imos_parameter_info('TIME', '_FillValue'))
    var_lat      = output_netcdf_obj.createVariable("LATITUDE", "d", "LATITUDE", fill_value=get_imos_parameter_info('LATITUDE', '_FillValue'))
    var_lon      = output_netcdf_obj.createVariable("LONGITUDE", "d", "LONGITUDE", fill_value=get_imos_parameter_info('LONGITUDE', '_FillValue'))
    var_depth    = output_netcdf_obj.createVariable("DEPTH", "f", "DEPTH", fill_value=get_imos_parameter_info('DEPTH', '_FillValue'))
    var_lat[:]   = input_netcdf_obj['LATITUDE'][:]
    var_lon[:]   = input_netcdf_obj['LONGITUDE'][:]
    var_depth[:] = depth_1d_interp

    main_var           = 'TEMP'
    fillvalue          = get_imos_parameter_info(main_var, '_FillValue')
    output_main_var    = output_netcdf_obj.createVariable(main_var, "f4", ("TIME", "DEPTH"), fill_value=fillvalue)
    output_main_var[:] = np.transpose(temp_gridded)
    output_main_var.coordinates = "TIME LONGITUDE LATITUDE DEPTH"

    # add gatts and variable attributes as stored in config files
    conf_file_generic = os.path.join(os.path.dirname(__file__), 'generate_nc_file_att')
    generate_netcdf_att(output_netcdf_obj, conf_file_generic, conf_file_point_of_truth=True)

    def add_var_att_from_input_nc_to_output_nc(var):
        input_var_object   = input_netcdf_obj[var]
        input_var_list_att = input_var_object.__dict__.keys()
        var_att_disposable = ['name', 'long_name', 'valid_min', 'valid_max', \
                              '_FillValue', 'ancillary_variables', \
                              'axis', 'ChunkSize', 'coordinates']
        for var_att in [att for att in input_var_list_att if att not in var_att_disposable]:
            setattr(output_netcdf_obj[var], var_att, getattr(input_netcdf_obj[var], var_att))

    add_var_att_from_input_nc_to_output_nc('DEPTH')
    add_var_att_from_input_nc_to_output_nc('LONGITUDE')
    add_var_att_from_input_nc_to_output_nc('LATITUDE')

    time_val_dateobj = date2num(time_1d_interp, output_netcdf_obj['TIME'].units, output_netcdf_obj['TIME'].calendar)
    var_time[:]      = time_val_dateobj

    output_netcdf_obj.time_coverage_start = min(time_1d_interp).strftime('%Y-%m-%dT%H:%M:%SZ')
    output_netcdf_obj.time_coverage_end   = max(time_1d_interp).strftime('%Y-%m-%dT%H:%M:%SZ')

    output_netcdf_obj.geospatial_vertical_min = float(np.min(depth_1d_interp))
    output_netcdf_obj.geospatial_vertical_max = float(np.max(depth_1d_interp))

    abstract = ("This product aggregates Temperature logger data collected at "
                "these nominal depths (%s) on the mooring line during the %s "
                "deployment by averaging them temporally and interpolating them "
                "vertically at consistent depths. The grid covers from %s to %s "
                "temporally and from %s to %s metres vertically. A cell is %s "
                "minutes wide and %s metre high") % (instrument_nominal_depth,
                                                output_netcdf_obj.deployment_code,
                                                output_netcdf_obj.time_coverage_start,
                                                output_netcdf_obj.time_coverage_end,
                                                output_netcdf_obj.geospatial_vertical_min,
                                                output_netcdf_obj.geospatial_vertical_max,
                                                output_netcdf_obj.temporal_resolution,
                                                output_netcdf_obj.vertical_resolution)

    output_netcdf_obj.abstract = abstract

    github_comment            = 'Product created with %s' % get_git_revision_script_url(os.path.realpath(__file__))
    output_netcdf_obj.lineage = ('%s. %s' % (getattr(output_netcdf_obj, 'lineage', ''), github_comment)).lstrip('. ')

    output_netcdf_obj.close()
    input_netcdf_obj.close()

    return output_netcdf_file_path

def create_fv02_product(nc_file_list):
    logger.info('creating FV02 product')
    depth_1d_interp, time_1d_interp = create_monotonic_grid_array(nc_file_list)
    temp, depth, time               = get_data_in_deployment(nc_file_list)
    temp_gridded                    = create_temp_interp_gridded(time_1d_interp, depth_1d_interp, temp, time, depth)

    output_file_name = generate_fv02_netcdf(temp_gridded, time_1d_interp, depth_1d_interp, nc_file_list)
    return output_file_name

def download_list_nc(list_url):
    """ Downloads a list of URL in a temporary directory """
    tmp_netcdf_fv01_dir = tempfile.mkdtemp()

    for url in list_url:
        file_name = url.split('/')[-1]
        u = urllib2.urlopen(url)
        f = open(os.path.join(tmp_netcdf_fv01_dir, file_name), 'wb')
        meta = u.info()
        file_size = int(meta.getheaders("Content-Length")[0])
        logger.info("Downloading: %s Bytes: %s" % (file_name, file_size))

        file_size_dl = 0
        block_sz = 65536
        while True:
            buffer = u.read(block_sz)
            if not buffer:
                break

            file_size_dl += len(buffer)
            f.write(buffer)
            status = r"%10d  [%3.2f%%]" % (file_size_dl, file_size_dl * 100. / file_size)
            status = status + chr(8)*(len(status)+1)
            logger.info(status)

        f.close()

    return tmp_netcdf_fv01_dir

def args():
    parser = argparse.ArgumentParser(description='Create FV02 ANMN temperature gridded product from FV01 deployment.\n return the path of the new FV02 file, and the relative path of the previously generated FV02 file')
    parser.add_argument('-f', "--incoming-file-path", dest='incoming_file_path', type=str, default='', help="incoming fv01 file to create grid product from", required=False)
    parser.add_argument('-d', "--deployment-code", dest='deployment_code', type=str, help="deployment_code netcdf global attribute", required=False)
    parser.add_argument('-o', '--output-dir', dest='output_dir', type=str, default=tempfile.mkdtemp(), help="output directory of FV02 netcdf file. (Optional)", required=False)
    parser.add_argument('-p', '--plot-old-new-prod-diff', dest='plot_comparison', action="store_true", default=False, help="plot the diff between the old and new version of the product. same path as FV02 nc file. (Optional)", required=False)
    vargs = parser.parse_args()

    if vargs.incoming_file_path != '':
        input_nc_obj          = Dataset(vargs.incoming_file_path, 'r')
        vargs.deployment_code = input_nc_obj.deployment_code

    if not os.path.exists(vargs.output_dir):
        logger.error('%s not a valid path' % vargs.output_dir)
        sys.exit(1)

    return vargs

def cleaning_err_exit():
    """ call function after an exception to clean data from temp dir """
    if fv01_dir:
        logger.info('Cleaning temporary data')
        shutil.rmtree(fv01_dir)
        sys.exit(1)

def main(incoming_file_path, deployment_code, output_dir, plot_comparison=False):
    global s3_bucket_prefix
    global logger
    global fv01_dir
    s3_bucket_prefix = 'https://s3-ap-southeast-2.amazonaws.com/imos-data'
    logging           = IMOSLogging()
    logger            = logging.logging_start(os.path.join(os.environ['WIP_DIR'], 'anmn_temp_grid.log'))
    list_fv01_url     = wfs_request_matching_file_pattern('anmn_ts_timeseries_map', '%%_FV01_%s%%' % deployment_code, s3_bucket_url=True)
    previous_fv02_url = wfs_request_matching_file_pattern('anmn_all_map', '%%Temperature/gridded/%%_FV02_%s_%%gridded%%' % deployment_code)

    if len(previous_fv02_url) == 1:
        previous_fv02_url = previous_fv02_url[0]
    else:
        previous_fv02_url = ''

    fv01_dir = download_list_nc(list_fv01_url)
    if incoming_file_path != '':
        # add incoming_file_path from user input arg to list of FV01 files to
        # process
        shutil.copy(incoming_file_path, fv01_dir)

    nc_fv01_list  = [os.path.join(fv01_dir, f) for f in os.listdir(fv01_dir)]
    if len(nc_fv01_list) < 2:
        logger.error('not enough FV01 file to create product')
        cleaning_err_exit()

    try:
        fv02_nc_path = create_fv02_product(nc_fv01_list)
        shutil.copy(fv02_nc_path, output_dir)
        shutil.rmtree(os.path.dirname(fv02_nc_path))
        fv02_nc_path = os.path.join(output_dir, os.path.basename(fv02_nc_path))

        if plot_comparison:
            if previous_fv02_url == '':
                logger.warning('no previous product available. comparison plot can not be created')
            else:
                plot_abs_comparison_old_new_product(previous_fv02_url, fv02_nc_path)
    except Exception as err:
        logger.error(err)
        cleaning_err_exit()

    shutil.rmtree(fv01_dir)
    return fv02_nc_path, previous_fv02_url


if __name__ == "__main__":
    """ examples
    ./anmn_temp_gridded_product.py -d WATR50-1004 -o . -p
    ./anmn_temp_gridded_product.py -d NRSKAI-1511
    ./anmn_temp_gridded_product.py -d NRSROT-1512 -p # to plot the difference between old and new prod
    ./anmn_temp_gridded_product.py -d WATR20-1407 -o /tmp

    wget http://thredds.aodn.org.au/thredds/fileServer/IMOS/ANMN/NRS/NRSKAI/Temperature/IMOS_ANMN-NRS_TZ_20151103T235900Z_NRSKAI_FV01_NRSKAI-1511-Aqualogger-520T-92_END-20160303T045900Z_C-20160502T063447Z.nc
    ./anmn_temp_gridded_product.py -f IMOS_ANMN-NRS_TZ_20151103T235900Z_NRSKAI_FV01_NRSKAI-1511-Aqualogger-520T-92_END-20160303T045900Z_C-20160502T063447Z.nc -p -o /tmp

    wget http://thredds.aodn.org.au/thredds/fileServer/IMOS/ANMN/NRS/NRSKAI/Temperature/IMOS_ANMN-NRS_TZ_20111216T000000Z_NRSKAI_FV01_NRSKAI-1112-Aqualogger-520T-94_END-20120423T034500Z_C-20160417T145834Z.nc
    ./anmn_temp_gridded_product.py -f IMOS_ANMN-NRS_TZ_20111216T000000Z_NRSKAI_FV01_NRSKAI-1112-Aqualogger-520T-94_END-20120423T034500Z_C-20160417T145834Z.nc
    ./anmn_temp_gridded_product.py -f IMOS_ANMN-NRS_TZ_20111216T000000Z_NRSKAI_FV01_NRSKAI-1112-Aqualogger-520T-94_END-20120423T034500Z_C-20160417T145834Z.nc -o $INCOMING_DIR/ANMN
    """
    vargs = args()
    fv02_nc_path, previous_fv02_url = main(vargs.incoming_file_path, vargs.deployment_code, vargs.output_dir, vargs.plot_comparison)
    print fv02_nc_path, previous_fv02_url
