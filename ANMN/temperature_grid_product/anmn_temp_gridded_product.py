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

import traceback
import argparse
import os
import re
import shutil
import sys
import tempfile
from datetime import datetime, timedelta

import numpy as np
from netCDF4 import Dataset, date2num, num2date

from generate_netcdf_att import generate_netcdf_att, get_imos_parameter_info
from imos_logging import IMOSLogging
from util import get_git_revision_script_url, wfs_request_matching_file_pattern, download_list_urls


def get_var_var_qc_in_deployment(varname, nc_file_list):
    """
    Return the variable values and its qc flags for all netcdf files in list
    """
    var, var_qc = [], []
    for f in nc_file_list:
        with Dataset(f, 'r') as netcdf_file_obj:
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

def get_min_max_var(var):
    """
    return the min and max values of temp, depth and time for a list of nc files
    """    
    max_var,  min_var  = [], []
    for ii in range(len(var)):
        max_var.append(np.max(var[ii]))
        min_var.append(np.min(var[ii]))

    max_var = max(max_var)
    min_var = min(min_var)
    
    return min_var, max_var

def daterange(date1, date2, step_in_seconds):
    for n in range(int(round(((date2 - date1).total_seconds()/step_in_seconds))) + 1):
        yield date1 + timedelta(seconds=n*step_in_seconds)

def create_time_common_grid(time_start, time_end, res_in_minutes):
    """
    create a 1D time array between start and end date rounded to a resolution
    of res_in_minutes and with values to possibly fall on the hour 00:00:00
    """
    time_interp_array = []
    
    time_start_msus = timedelta(minutes=time_start.minute, seconds=time_start.second, microseconds=time_start.microsecond)
    time_end_msus   = timedelta(minutes=time_end.minute,   seconds=time_end.second,   microseconds=time_end.microsecond)
    
    time_start_rounded = datetime(time_start.year, time_start.month, time_start.day, time_start.hour)
    time_end_rounded   = datetime(time_end.year,   time_end.month,   time_end.day,   time_end.hour)
    
    res_in_seconds = res_in_minutes*60
    
    time_start_rounded = time_start_rounded + timedelta(seconds=np.round(time_start_msus.total_seconds()/res_in_seconds)*res_in_seconds)
    time_end_rounded   = time_end_rounded   + timedelta(seconds=np.round(time_end_msus.total_seconds()  /res_in_seconds)*res_in_seconds)
    
    for dt in daterange(time_start_rounded, time_end_rounded, res_in_seconds):
        time_interp_array.append(dt)
    
    return time_interp_array

def create_monotonic_grid_array(depth, time):
    """
    create the depth and time common grid array.
    """
    min_depth,  max_depth = get_min_max_var(depth)
    time_start, time_end  = get_min_max_var(time)
    depth_common_grid = range(int(np.ceil(min_depth/vertical_res_in_metres)*vertical_res_in_metres), 
                     int(np.floor(max_depth/vertical_res_in_metres)*vertical_res_in_metres) + 1, 
                     vertical_res_in_metres)
    time_common_grid  = create_time_common_grid(time_start, time_end, temporal_res_in_minutes)

    return depth_common_grid, time_common_grid

def create_temp_interp_gridded(time_common_grid, depth_common_grid, temp_values, time_values, depth_values):
    """
    create the interpolated gridded temperature data. The reference grid is time_1d_interp,
    and depth_1d_interp.
    We first look for temp values within time bins, average them, and then do a
    linear interpolation over the depth
    """    
    n_file = len(temp_values)
    n_depth = len(depth_common_grid)
    n_time = len(time_common_grid)
    # initialise with nan
    temp_gridded = np.full((n_depth, n_time), np.nan)
    
    temp_binned_array  = []
    depth_binned_array = []
    
    time_delta = (time_common_grid[1]- time_common_grid[0])
        
    time_bins_start = []
    for j in range(n_time):
        time_bins_start.append(time_common_grid[j] - time_delta/2) # time_1d_interp sits in the centre of the bin

    time_bins_start.append(time_common_grid[j] + time_delta/2) # add last value

    # histogram doesn't work with datetime so we need to use timestamps in seconds since a reference date
    unit_in_seconds_since_arbitrary_date = 'seconds since 1950-01-01 00:00:00 UTC'
    arbitrary_calendar = 'gregorian'
    timestamp_bins_start = date2num(time_bins_start, unit_in_seconds_since_arbitrary_date, arbitrary_calendar)
    
    # temporal binning per dataset
    for i_file in range(n_file):        
        timestamp_values = date2num(time_values[i_file], unit_in_seconds_since_arbitrary_date, arbitrary_calendar)
        
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
        ii = np.argsort(depth_binned)
        depth_binned = depth_binned[ii]
        temp_binned  = temp_binned [ii]
        
        # we only want to interpolate what's between the depth_binned range, what is below or above is nan
        temp_gridded[:,j] = np.interp(depth_common_grid, depth_binned, temp_binned, left=np.nan, right=np.nan)
    
    return temp_gridded

def list_instrument_meta(nc_file_list):
    """ return a list of file / nominal_depth / sample_interval / serial_number gatt ordered by nominal_depth from the nc_file_list"""
    instrument_nominal_depth   = []
    instrument_sample_interval = []
    instrument_serial_number   = []
    for f in nc_file_list:
        with Dataset(f, 'r') as netcdf_file_obj:
            instrument_nominal_depth.append(netcdf_file_obj.instrument_nominal_depth)
            instrument_sample_interval.append(netcdf_file_obj.instrument_sample_interval)
            instrument_serial_number.append(netcdf_file_obj.instrument_serial_number)

    # we sort these metadata info by nominal depth
    nc_file_list               = [x for _,x in sorted(zip(instrument_nominal_depth, nc_file_list))]
    instrument_sample_interval = [x for _,x in sorted(zip(instrument_nominal_depth, instrument_sample_interval))]
    instrument_serial_number   = [x for _,x in sorted(zip(instrument_nominal_depth, instrument_serial_number))]
    instrument_nominal_depth.sort()
    
    return nc_file_list, instrument_nominal_depth, instrument_sample_interval, instrument_serial_number

def generate_fv02_filename(time_1d_interp, nc_file_list):
    """ return the file name only of the FV02 product """
    with Dataset(nc_file_list[0], 'r') as netcdf_file_obj:
        site_code         = netcdf_file_obj.site_code
        deployment_code   = netcdf_file_obj.deployment_code
        
    input_netcdf_name = os.path.basename(nc_file_list[0])
    pattern           = re.compile("^(IMOS_.*)_([A-Z].*)_([0-9]{8}T[0-9]{6}Z)_(.*)_FV01_(.*)_END")
    match_group       = pattern.match(input_netcdf_name)

    time_start  = min(time_1d_interp).strftime('%Y%m%dT%H%M%SZ')
    time_end    = max(time_1d_interp).strftime('%Y%m%dT%H%M%SZ')

    output_netcdf_name = '%s_T_%s_%s_FV02_%s-gridded_END-%s.nc' % (match_group.group(1), time_start,
                                                                    site_code, deployment_code, time_end)
    return output_netcdf_name

def generate_fv02_netcdf(temp_gridded, time_1d_interp, depth_1d_interp, nc_file_list, output_dir):
    """ generated the FV02 temperature gridded product netcdf file """
    output_netcdf_file_path = os.path.join(output_dir, generate_fv02_filename(time_1d_interp, nc_file_list))

    with Dataset(nc_file_list[0], 'r') as input_netcdf_obj, Dataset(output_netcdf_file_path, "w", format="NETCDF4") as output_netcdf_obj:
        output_netcdf_obj.date_created = datetime.now().strftime("%Y-%m-%dT%H:%M:%SZ")

        # read gatts from input, add them to output. Some gatts will be overwritten
        input_gatts     = input_netcdf_obj.ncattrs()
        gatt_to_dispose = ['author', 'author_email', 'cdm_data_type', 'comment', 'Conventions', 'toolbox_input_file', 'toolbox_version', 'file_version', 'file_version_quality_control', 'quality_control_set',
                           'quality_control_log', 'CoordSysBuilder_', 'date_created', 'netcdf_filename', 'metadata', 'instrument', 'instrument_serial_number',
                           'instrument_nominal_depth', 'instrument_nominal_height', 'instrument_sample_interval', 'compliance_checker_version', 'compliance_checker_last_updated',
                           'geospatial_vertical_min', 'geospatial_vertical_max', 'keywords', 'featureType',
                           'time_deployment_start_origin' , 'time_deployment_end_origin']


        for gatt in input_gatts:
            if gatt not in gatt_to_dispose:
                setattr(output_netcdf_obj, gatt, getattr(input_netcdf_obj, gatt))

        setattr(output_netcdf_obj, 'featureType', "timeSeriesProfile")
        setattr(output_netcdf_obj, 'temporal_resolution', np.float64(temporal_res_in_minutes))
        setattr(output_netcdf_obj, 'vertical_resolution', np.float32(vertical_res_in_metres))
        setattr(output_netcdf_obj, 'history', output_netcdf_obj.date_created + " - " + os.path.basename(__file__) + ".")
        setattr(output_netcdf_obj, 'keywords', 'Temperature regridded, TIME, LATITUDE, LONGITUDE, DEPTH, TEMP')

        nc_file_list, instrument_nominal_depth, instrument_sample_interval, instrument_serial_number = list_instrument_meta(nc_file_list)
    
        setattr(output_netcdf_obj, 'input_file', ", ".join([os.path.basename(x) for x in nc_file_list]))
        setattr(output_netcdf_obj, 'instrument_nominal_depth', ", ".join(map(str, instrument_nominal_depth)))
        setattr(output_netcdf_obj, 'instrument_sample_interval', ", ".join(map(str, instrument_sample_interval)))
        setattr(output_netcdf_obj, 'instrument_serial_number', ", ".join(instrument_serial_number))

        output_netcdf_obj.createDimension("TIME", temp_gridded.shape[1])
        output_netcdf_obj.createDimension("DEPTH", temp_gridded.shape[0])

        var_time     = output_netcdf_obj.createVariable("TIME", "d", "TIME")
        var_time.comment = "Time stamp corresponds to the centre of the averaging cell."
        
        var_depth    = output_netcdf_obj.createVariable("DEPTH", "f", "DEPTH")
        var_depth.axis = "Z"
        var_depth[:] = depth_1d_interp
                 
        var_id       = output_netcdf_obj.createVariable("TIMESERIESPROFILE", "i", ())
        var_id.long_name = "unique_identifier_for_each_timeseriesprofile_feature_instance_in_this_file"
        var_id.cf_role   = "timeseries_id"
        var_id[:] = 1
        
        var_lat      = output_netcdf_obj.createVariable("LATITUDE", "d", ())
        var_lon      = output_netcdf_obj.createVariable("LONGITUDE", "d", ())
        var_lat[:]   = input_netcdf_obj['LATITUDE'][:]
        var_lon[:]   = input_netcdf_obj['LONGITUDE'][:]
        
        var_temp     = output_netcdf_obj.createVariable("TEMP", "f", ("TIME", "DEPTH"), 
                                                        fill_value=get_imos_parameter_info('TEMP', '_FillValue'), 
                                                        zlib=True, 
                                                        complevel=1, 
                                                        shuffle=True, 
                                                        chunksizes=(temp_gridded.shape[1], temp_gridded.shape[0]))
        var_temp.coordinates = "TIME LATITUDE LONGITUDE DEPTH"
        var_temp[:]  = np.transpose(temp_gridded)

        # add gatts and variable attributes as stored in config files
        conf_file_generic = os.path.join(os.path.dirname(__file__), 'generate_nc_file_att')
        generate_netcdf_att(output_netcdf_obj, conf_file_generic, conf_file_point_of_truth=True)

        def add_var_att_from_input_nc_to_output_nc(var):
            input_var_object   = input_netcdf_obj[var]
            input_var_list_att = input_var_object.ncattrs()
            var_att_disposable = ['name', \
                                  '_FillValue', 'ancillary_variables', \
                                  'ChunkSize', 'coordinates', 'comment']
            for var_att in [att for att in input_var_list_att if att not in var_att_disposable]:
                setattr(output_netcdf_obj[var], var_att, getattr(input_netcdf_obj[var], var_att))

        add_var_att_from_input_nc_to_output_nc('TIME')
        add_var_att_from_input_nc_to_output_nc('LATITUDE')
        add_var_att_from_input_nc_to_output_nc('LONGITUDE')
        add_var_att_from_input_nc_to_output_nc('DEPTH')
        add_var_att_from_input_nc_to_output_nc('TEMP')

        time_val_dateobj = date2num(time_1d_interp, var_time.units, var_time.calendar)
        var_time[:]      = time_val_dateobj

        output_netcdf_obj.time_coverage_start = min(time_1d_interp).strftime('%Y-%m-%dT%H:%M:%SZ')
        output_netcdf_obj.time_coverage_end   = max(time_1d_interp).strftime('%Y-%m-%dT%H:%M:%SZ')

        output_netcdf_obj.geospatial_vertical_min = float(np.min(depth_1d_interp))
        output_netcdf_obj.geospatial_vertical_max = float(np.max(depth_1d_interp))

        output_netcdf_obj.abstract = (("This product aggregates Temperature logger data collected at "
                    "on a mooring line during a deployment by averaging them temporally in cells of %s minutes wide and interpolating them "
                    "vertically every %s metres at consistent depths. ") % (output_netcdf_obj.temporal_resolution, output_netcdf_obj.vertical_resolution) 
                    + output_netcdf_obj.abstract)

        github_comment            = 'Product created with %s' % get_git_revision_script_url(os.path.realpath(__file__))
        output_netcdf_obj.lineage = ('%s %s' % (getattr(output_netcdf_obj, 'lineage', ''), github_comment))

    return output_netcdf_file_path

def create_fv02_product(nc_file_list, output_dir):
    logger.info('creating FV02 product')
    temp, depth, time                   = get_data_in_deployment(nc_file_list)
    depth_common_grid, time_common_grid = create_monotonic_grid_array(depth, time)
    temp_gridded                        = create_temp_interp_gridded(time_common_grid, depth_common_grid, temp, time, depth)

    output_file_name = generate_fv02_netcdf(temp_gridded, time_common_grid, depth_common_grid, nc_file_list, output_dir)
    return output_file_name

def get_usable_fv01_list(fv01_dir):
    nc_usable_file_list = []
    
    nc_file_list = [os.path.join(fv01_dir, f) for f in os.listdir(fv01_dir)]
    
    required_vars = ['TIME', 'TEMP', 'DEPTH']
    
    for f in nc_file_list:
        with Dataset(f, 'r') as netcdf_file_obj:
            is_usable = all(var in netcdf_file_obj.variables for var in required_vars)
            
        if is_usable:
            nc_usable_file_list.append(f)
    
    return nc_usable_file_list

def args():
    parser = argparse.ArgumentParser(description='Creates FV02 ANMN temperature gridded product from FV01 files found in a deployment.\n Returns the path of the new locally generated FV02 file, and the relative path of the previously generated FV02 file.')
    parser.add_argument('-f', "--incoming-file-path", dest='incoming_file_path', type=str, default='', help="incoming fv01 file to create grid product from", required=False)
    parser.add_argument('-d', "--deployment-code", dest='deployment_code', type=str, help="deployment_code netcdf global attribute", required=False)
    parser.add_argument('-o', '--output-dir', dest='output_dir', type=str, default=tempfile.mkdtemp(), help="output directory of FV02 netcdf file. (Optional)", required=False)
    vargs = parser.parse_args()

    if os.path.isfile(vargs.incoming_file_path):
        with Dataset(vargs.incoming_file_path, 'r') as input_nc_obj:
            vargs.deployment_code = input_nc_obj.deployment_code

    if not os.path.exists(vargs.output_dir):
        logger.error('%s not a valid path' % vargs.output_dir)
        sys.exit(1)

    return vargs

def cleanup():
    """ call function to clean up temp dir """
    if fv01_dir is not None:
        shutil.rmtree(fv01_dir)

def main(incoming_file_path, deployment_code, output_dir):
    global logger
    global temporal_res_in_minutes
    global vertical_res_in_metres
    
    temporal_res_in_minutes = 60.0
    vertical_res_in_metres  = 1 # has to be an integer since used in range() later
    fv02_nc_path      = None
    logging           = IMOSLogging()
    logger            = logging.logging_start(os.path.join(output_dir, 'anmn_temp_grid.log'))
    list_fv01_url     = wfs_request_matching_file_pattern('anmn_ts_timeseries_map', '%%_FV01_%s%%' % deployment_code, s3_bucket_url=True, url_column='file_url')
    previous_fv02_url = wfs_request_matching_file_pattern('anmn_all_map', '%%Temperature/gridded/%%_FV02_%s_%%gridded%%' % deployment_code)

    if len(previous_fv02_url) == 1:
        previous_fv02_url = previous_fv02_url[0]

    logger.info("Downloading files:\n%s" % "\n".join(map(str, [os.path.basename(fv01_url) for fv01_url in list_fv01_url])))
    fv01_dir = download_list_urls(list_fv01_url)

    nc_fv01_list  = get_usable_fv01_list(fv01_dir)
    
    if len(nc_fv01_list) < 2:
        logger.error('not enough FV01 file to create product')
    else:
        fv02_nc_path = create_fv02_product(nc_fv01_list, output_dir)

    return fv02_nc_path, previous_fv02_url


if __name__ == "__main__":
    """ examples
    ./anmn_temp_gridded_product.py -d WATR50-1004 -o .
    ./anmn_temp_gridded_product.py -d NRSKAI-1511
    ./anmn_temp_gridded_product.py -d NRSROT-1512
    ./anmn_temp_gridded_product.py -d WATR20-1407 -o /tmp

    wget http://thredds.aodn.org.au/thredds/fileServer/IMOS/ANMN/NRS/NRSKAI/Temperature/IMOS_ANMN-NRS_TZ_20151103T235900Z_NRSKAI_FV01_NRSKAI-1511-Aqualogger-520T-92_END-20160303T045900Z_C-20160502T063447Z.nc
    ./anmn_temp_gridded_product.py -f IMOS_ANMN-NRS_TZ_20151103T235900Z_NRSKAI_FV01_NRSKAI-1511-Aqualogger-520T-92_END-20160303T045900Z_C-20160502T063447Z.nc -o /tmp

    wget http://thredds.aodn.org.au/thredds/fileServer/IMOS/ANMN/NRS/NRSKAI/Temperature/IMOS_ANMN-NRS_TZ_20111216T000000Z_NRSKAI_FV01_NRSKAI-1112-Aqualogger-520T-94_END-20120423T034500Z_C-20160417T145834Z.nc
    ./anmn_temp_gridded_product.py -f IMOS_ANMN-NRS_TZ_20111216T000000Z_NRSKAI_FV01_NRSKAI-1112-Aqualogger-520T-94_END-20120423T034500Z_C-20160417T145834Z.nc
    ./anmn_temp_gridded_product.py -f IMOS_ANMN-NRS_TZ_20111216T000000Z_NRSKAI_FV01_NRSKAI-1112-Aqualogger-520T-94_END-20120423T034500Z_C-20160417T145834Z.nc -o $INCOMING_DIR/ANMN
    """
    global fv01_dir
    fv01_dir = None
    
    try:
        vargs = args()
        fv02_nc_path, previous_fv02_url = main(vargs.incoming_file_path, vargs.deployment_code, vargs.output_dir)
        if fv02_nc_path is not None:
            print fv02_nc_path, previous_fv02_url
    
    except Exception:
        logger.error(traceback.print_exc())
        sys.exit(1)
        
    finally:
        cleanup()
