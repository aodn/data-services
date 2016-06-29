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


from datetime import datetime, timedelta
from generate_netcdf_att import generate_netcdf_att, get_imos_parameter_info
from imos_logging import IMOSLogging
from matplotlib import gridspec
from netCDF4 import Dataset, num2date, date2num
from util import get_git_revision_script_url
from util import wfs_request_matching_file_pattern
import argparse
import bisect
import numpy as np
import os
import pandas as pd
import pylab as pl
import re
import sys
import shutil
import tempfile
import urllib2


def plot_abs_comparaison_old_new_product(old_product_rel_path, new_nc_path):
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
    y = df.index.values
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

    product_version_comparaison_path = os.path.splitext(new_nc_path)[0] + '.png'
    pl.savefig(product_version_comparaison_path)
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

def get_data_in_deployment(nc_file_list):
    """
    return depth, time and temp data with flags 1 and 2 for all nc files
    """
    temp, temp_qc   = get_var_var_qc_in_deployment('TEMP', nc_file_list)
    depth, depth_qc = get_var_var_qc_in_deployment('DEPTH', nc_file_list)
    time, time_qc   = get_var_var_qc_in_deployment('TIME', nc_file_list)

    # keep FLAGS == 1, 2
    for id in range(len(temp_qc)):
        temp_qc_idx_to_keep  = [a or b for a, b in zip(temp_qc[id] == 1, temp_qc[id] == 2)]
        time_qc_idx_to_keep  = [a or b for a, b in zip(time_qc[id] == 1, time_qc[id] == 2)]
        depth_qc_idx_to_keep = [a or b for a, b in zip(depth_qc[id] == 1, depth_qc[id] == 2)]
        temp_qc_idx_to_keep  = [a and b for a, b in zip(temp_qc_idx_to_keep, time_qc_idx_to_keep)]
        temp_qc_idx_to_keep  = [a and b for a, b in zip(temp_qc_idx_to_keep, depth_qc_idx_to_keep)]

        temp[id]  = np.array([val for is_good, val in zip(temp_qc_idx_to_keep, temp[id]) if is_good])
        time[id]  = np.array([val for is_good, val in zip(temp_qc_idx_to_keep, time[id]) if is_good])
        depth[id] = np.array([val for is_good, val in zip(temp_qc_idx_to_keep, depth[id]) if is_good])

    return temp, depth, time

def get_min_max_var_deployment(nc_file_list, varname):
    """
    return the min and max values of a variable for a list of nc files
    """
    var, var_qc = get_var_var_qc_in_deployment(varname, nc_file_list)

    # var can have a range of mask and non mask arrays unfortunately
    max_var, min_var = [], []
    for ii in range(len(var)):
        max_var.append(np.max(var[ii]))
        min_var.append(np.min(var[ii]))

    max_var = max(max_var)
    min_var = min(min_var)

    return min_var, max_var

def _perdelta(start, end, delta):
        curr = start
        while curr < end:
            yield curr
            curr += delta

def create_time_1d(time_start, time_end, delta_in_minutes):
    """
    create a 1D time array between start and end date and a data step of delta_in_minute
    """
    time_interp_array = []
    for result in _perdelta(time_start + timedelta(minutes=delta_in_minutes)/2,
                            time_end - timedelta(minutes=delta_in_minutes)/2,
                            timedelta(minutes=delta_in_minutes)):
        time_interp_array.append(result)

    return time_interp_array

def create_monotonic_grid_array(nc_file_list):
    """
    create the interpolated depth and time array. The depth interpolation is 1 meter
    """
    min_depth, max_depth = get_min_max_var_deployment(nc_file_list, 'DEPTH')
    depth_1d_1meter      = range(min_depth, max_depth, 1)

    time_start, time_end    = get_min_max_var_deployment(nc_file_list, 'TIME')
    avrg_window, n_val_step = get_frequency_step_in_deployment(nc_file_list)
    time_1d_interp          = create_time_1d(time_start, time_end, delta_in_minutes=avrg_window)

    return depth_1d_1meter, time_1d_interp

def get_frequency_step_in_deployment(nc_file_list):
    """
    for a list of FV01 files, get the maximum instrument sample interval to get back
    the time range
    """
    sample_interval = []
    for f in nc_file_list:
        netcdf_file_obj = Dataset(f, 'r')

        # this part is not yet used as we don't use WQM files, but could maybe
        # be used in the future depending of FV01 QC quality
        if hasattr(netcdf_file_obj, 'instrument_burst_interval'):
            sample_interval.append(netcdf_file_obj.instrument_burst_interval)
        elif hasattr(netcdf_file_obj, 'instrument_sample_interval'):
            sample_interval.append(netcdf_file_obj.instrument_sample_interval)
        netcdf_file_obj.close()

    def _sample_inter(sample_interval):
        if round(sample_interval) == 50 or round(sample_interval) < 120:
            average_window = 30
            n_val_step     = 20
        elif round(sample_interval) == 120 or round(sample_interval) < 300:
            average_window = 30
            n_val_step     = 10
        elif round(sample_interval) == 300 or round(sample_interval) < 600:
            average_window = 30
            n_val_step     = 3
        elif round(sample_interval) == 600 or round(sample_interval) < 900:
            average_window = 30
            n_val_step     = 2
        elif round(sample_interval) == 900 or round(sample_interval) < 1200:
            average_window = 60
            n_val_step     = 3
        elif round(sample_interval) >= 1200:
            average_window = 90
            n_val_step     = 3

        return average_window, n_val_step

    sample_interval_uniq  = set(sample_interval)
    if len(sample_interval_uniq) > 1:
        logger.warning('Deployment has multiple instrument_sample_interval')

    average_window, n_val_step = [], []
    for sample_id in range(len(sample_interval_uniq)):
        sample = sample_interval_uniq.pop()
        aa, bb = _sample_inter(sample)
        average_window.append(aa)
        n_val_step.append(bb)

    return max(average_window), n_val_step[average_window.index(max(average_window))]

def find_closest(A, target):
    #A must be sorted
    idx    = A.searchsorted(target)
    idx    = np.clip(idx, 1, len(A)-1)
    left   = A[idx-1]
    right  = A[idx]
    idx   -= target - left < right - target
    return idx

def create_temp_interp_gridded(time_1d_interp, depth_1d_interp, temp_values, time_values, depth_values, n_valid_t_step):
    """
    create the interpolated gridded temperature data. The reference grid is time_1d_interp,
    and depth_1d_interp.
    We first look for temp values within a time bin, average them, and then do a
    linear interpolation over the depth
    """
    # initialise with nan
    temp_gridded = [[np.nan]*len(time_1d_interp) for _ in range(len(depth_1d_interp))]
    n_depth_file = len(temp_values)
    for id in range(n_depth_file):
        # binning of time
        time_delta = (time_1d_interp[1]- time_1d_interp[0])
        for t_gridded_idx in range(len(time_1d_interp)-1):
            lower = bisect.bisect_left(time_values[id], time_1d_interp[t_gridded_idx] - time_delta/2 )
            upper = bisect.bisect_left(time_values[id], time_1d_interp[t_gridded_idx + 1] - time_delta/2)-1
            time_indexes_cell = range(lower, upper + 1)

            depth_uniq_time = depth_values[id][time_indexes_cell]
            depth_idx_eq    = find_closest(np.array(depth_1d_interp), depth_uniq_time)

            for array_index, d_gridded_idx in enumerate(depth_idx_eq):
                # idx_time can be linked to more than one real value for one
                # cell in the gridded product, so we do an average of those
                temp_gridded[d_gridded_idx][t_gridded_idx] = np.nanmean([temp_gridded[d_gridded_idx][t_gridded_idx], temp_values[id][time_indexes_cell][array_index]])

    # remove NaN off depth edges of pandas grid
    def trim_nans_off_rows(df):
        first_idx = df.first_valid_index()
        last_idx  = df.last_valid_index()
        df        = df.loc[first_idx:last_idx]
        return df

    df = pd.DataFrame(temp_gridded, columns=time_1d_interp, index=depth_1d_interp)
    try:
        df = df.interpolate(method='slinear', axis=0, limit_direction='both') #depth
        df = df.interpolate(method='linear', axis=1, limit=n_valid_t_step)
    except Exception as err:
        logger.error('error with interpolation method - %s' % err)
        cleaning_err_exit()

    df = trim_nans_off_rows(df)
    df = df.transpose()
    df = trim_nans_off_rows(df)
    df = df.transpose()
    return df

def list_instrument_nominal_depth(nc_file_list):
    """ return a list of nominal_depth gatt from the nc files"""
    instrument_nominal_depth = []
    for f in nc_file_list:
        netcdf_file_obj = Dataset(f, 'r')
        instrument_nominal_depth.append(netcdf_file_obj.instrument_nominal_depth)
        netcdf_file_obj.close()
    return instrument_nominal_depth

def generate_fv02_filename(df, nc_file_list):
    """ return the file name only of the FV02 product """
    netcdf_file_obj   = Dataset(nc_file_list[0], 'r')
    site_code         = netcdf_file_obj.site_code
    deployment_code   = netcdf_file_obj.deployment_code
    input_netcdf_name = os.path.basename(nc_file_list[0])
    pattern           = re.compile("^(IMOS_.*)_([A-Z].*)_([0-9]{8}T[0-9]{6}Z)_(.*)_FV01_(.*)_END")
    match_group       = pattern.match(input_netcdf_name)

    time_values = transform_datetime64_datetime(df.columns.values)
    time_start  = min(time_values).strftime('%Y%m%dT%H%M%SZ')
    time_end    = max(time_values).strftime('%Y%m%dT%H%M%SZ')

    output_netcdf_name = '%s_T_%s_%s_FV02_%s_gridded_END-%s.nc' % (match_group.group(1), time_start,
                                                                    site_code, deployment_code, time_end)

    netcdf_file_obj.close()
    return output_netcdf_name

def transform_datetime64_datetime(datetime64_object):
    """ The pandas date object is turned into a datetime64 type. This creates an issue when
    doing a normal datetime operation which is fixed by running this function """
    # http://stackoverflow.com/questions/13703720/converting-between-datetime-timestamp-and-datetime64
    ns          = 1e-9 # nanoseconds
    time_values = [datetime.utcfromtimestamp(x.astype(int) * ns) for x  in datetime64_object]
    return time_values

def generate_fv02_netcdf(df, nc_file_list):
    """ generated the FV02 temperature gridded product netcdf file """
    tmp_netcdf_dir          = tempfile.mkdtemp()
    output_netcdf_file_path = os.path.join(tmp_netcdf_dir, generate_fv02_filename(df, nc_file_list))

    input_netcdf_obj               = Dataset(nc_file_list[0], 'r')
    output_netcdf_obj              = Dataset(output_netcdf_file_path, "w", format="NETCDF4")
    output_netcdf_obj.date_created = datetime.now().strftime("%Y-%m-%dT%H:%M:%SZ")

    # read gatts from input, add them to output. Some gatts will be overwritten
    input_gatts     = input_netcdf_obj.__dict__.keys()
    gatt_to_dispose = ['author', 'toolbox_input_file', 'file_version', 'file_version_quality_control', 'quality_control_set',
                       'CoordSysBuilder_', 'netcdf_filename', 'metadata', 'instrument_serial_number',
                       'instrument_nominal_depth', 'compliance_checker_version', 'compliance_checker_last_updated',
                       'geospatial_vertical_min', 'geospatial_vertical_max', 'featureType']

    for gatt in input_gatts:
        if gatt not in gatt_to_dispose:
            setattr(output_netcdf_obj, gatt, getattr(input_netcdf_obj, gatt))

    comment = 'comment: The following files have been used to generate the gridded product:\n%s' % " \n".join([os.path.basename(x) for x in nc_file_list])
    setattr(output_netcdf_obj, 'comment', comment)
    setattr(output_netcdf_obj, 'temporal_resolution', get_frequency_step_in_deployment(nc_file_list)[0] )
    setattr(output_netcdf_obj, 'vertical_resolution', 1 )

    instrument_nominal_depth = ", ".join(map(str, list_instrument_nominal_depth(nc_file_list)))
    setattr(output_netcdf_obj, 'instrument_nominal_depth', instrument_nominal_depth)

    output_netcdf_obj.createDimension("TIME", len(df.columns))
    output_netcdf_obj.createDimension("DEPTH", len(df.index))
    output_netcdf_obj.createDimension("LATITUDE", 1)
    output_netcdf_obj.createDimension("LONGITUDE", 1)

    var_time     = output_netcdf_obj.createVariable("TIME", "d", "TIME", fill_value=get_imos_parameter_info('TIME', '_FillValue'))
    var_lat      = output_netcdf_obj.createVariable("LATITUDE", "d", "LATITUDE", fill_value=get_imos_parameter_info('LATITUDE', '_FillValue'))
    var_lon      = output_netcdf_obj.createVariable("LONGITUDE", "d", "LONGITUDE", fill_value=get_imos_parameter_info('LONGITUDE', '_FillValue'))
    var_depth    = output_netcdf_obj.createVariable("DEPTH", "f", "DEPTH", fill_value=get_imos_parameter_info('DEPTH', '_FillValue'))
    var_lat[:]   = input_netcdf_obj['LATITUDE'][:]
    var_lon[:]   = input_netcdf_obj['LONGITUDE'][:]
    var_depth[:] = df.index.values

    main_var           = 'TEMP'
    fillvalue          = get_imos_parameter_info(main_var, '_FillValue')
    output_main_var    = output_netcdf_obj.createVariable(main_var, "f4", ("TIME", "DEPTH"), fill_value=fillvalue)
    output_main_var[:] = df.values.transpose()
    output_main_var.coordinates = "TIME DEPTH"

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

    # convert datetime64 to datetime
    time_values      = transform_datetime64_datetime(df.columns.values)
    time_val_dateobj = date2num(time_values, output_netcdf_obj['TIME'].units, output_netcdf_obj['TIME'].calendar)
    var_time[:]      = time_val_dateobj

    output_netcdf_obj.time_coverage_start = min(time_values).strftime('%Y-%m-%dT%H:%M:%SZ')
    output_netcdf_obj.time_coverage_end   = max(time_values).strftime('%Y-%m-%dT%H:%M:%SZ')

    output_netcdf_obj.geospatial_vertical_min = float(df.index.values.min())
    output_netcdf_obj.geospatial_vertical_max = float(df.index.values.max())

    abstract = ("This product aggregates Temperature logger data collected at "
                "these nominal depths (%s) on the mooring line during the %s "
                "deployment by averaging them temporally and interpolating them "
                "vertically on a common grid. The grid covers from %s to %s "
                "temporally and from %s to %s metres vertically. A cell is %s "
                "minutes wide and %s metre high") % (instrument_nominal_depth,
                                                output_netcdf_obj.deployment_code,
                                                output_netcdf_obj.time_coverage_start,
                                                output_netcdf_obj.time_coverage_end,
                                                df.index.values.min(),
                                                df.index.values.max(),
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
    n_valid_t_step                  = get_frequency_step_in_deployment(nc_file_list)[1]
    temp_gridded                    = create_temp_interp_gridded(time_1d_interp, depth_1d_interp, temp, time, depth, n_valid_t_step)

    output_file_name = generate_fv02_netcdf(temp_gridded, nc_file_list)
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
    parser.add_argument('-p', '--plot-old-new-prod-diff', dest='plot_comparaison', action="store_true", default=False, help="plot the diff between the old and new version of the product. same path as FV02 nc file. (Optional)", required=False)
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

def main(incoming_file_path, deployment_code, output_dir, plot_comparaison=False):
    global s3_bucket_prefix
    global logger
    global fv01_dir
    s3_bucket_prefix = 'https://s3-ap-southeast-2.amazonaws.com/imos-data'
    logging           = IMOSLogging()
    logger            = logging.logging_start(os.path.join(os.environ['WIP_DIR'], 'anmn_temp_grid.log'))
    list_fv01_url     = wfs_request_matching_file_pattern('anmn_all_map', '%%Temperature/%%_TZ_%%_FV01_%s%%' % deployment_code, s3_bucket_url=True)
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

        if plot_comparaison:
            if previous_fv02_url == '':
                logger.warning('no previous product available. comparaison plot can not be created')
            else:
                plot_abs_comparaison_old_new_product(previous_fv02_url, fv02_nc_path)
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
    fv02_nc_path, previous_fv02_url = main(vargs.incoming_file_path, vargs.deployment_code, vargs.output_dir, vargs.plot_comparaison)
    print fv02_nc_path, previous_fv02_url
