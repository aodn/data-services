#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Burst Average Product creation from WQM and CTD FV01 files
./burst_average_product.py input_netcdf.nc /output_dir
"""
from datetime import datetime
from file_classifier import MooringFileClassifier
from generate_netcdf_att import generate_netcdf_att, get_imos_parameter_info
from math import isnan
from netCDF4 import Dataset, num2date, date2num
import argparse
import inspect
import numpy as np
import os
import pandas as pd
import re
import shutil
import sys
import tempfile
import time


def get_input_file_rel_path(input_netcdf_file_path):
    """
    find the relative path hierarchy of an input FV01 file. The value will be
    used in a gatt of the burst netcdf file
    """
    return MooringFileClassifier.dest_path(input_netcdf_file_path)

def min_bad_qc_flag(varname):
    """returns the min IMOS IODE qc flag value to get rid of per variable"""
    default_min_qc_flag_value = 3
    dict_var = {
        'CHLF':     4,
        'CHLR':     4,
        'CHLU':     4,
        'CPHL':     4,
        'DOX1_2':   3,
        'DOX2':     3,
        'FLU2':     4,
        'FLNTU':    4,
        'PRES_REL': 4,
        'PSAL':     4,
        'TEMP':     4,
        'TURB':     4,
    }

    if varname in dict_var.keys():
        return dict_var[varname]
    else:
        return default_min_qc_flag_value

def create_burst_average_var(netcdf_file_obj):
    """
    create burst data from all vars available in netcdf
    """
    time_values              = get_time_val(netcdf_file_obj)
    varname_to_burst_average = list_var_to_average(netcdf_file_obj)
    burst_vars               = {}

    for varname in varname_to_burst_average:
        var_values, var_qc_flag_exclusion = get_var_val_var_qc_exclusion(
            netcdf_file_obj, varname, min_bad_qc_flag(varname)
        )

        burst_vars[varname] = burst_average_data(time_values, var_values, var_qc_flag_exclusion)

    return clean_burst_vars(burst_vars)

def clean_burst_vars(burst_vars):
    """
    For every burst var created, look for the first index of non NaN value. The
    lower value will be the one kept, and the new start index of each burst variable
    including the TIME.
    """
    min_index = None
    for var in burst_vars.keys():
        var_mean_burst = burst_vars[var]['var_mean'] # first non TIME product
        if not np.isnan(var_mean_burst).all():
            min_index_var  = next(x for x, y in enumerate(var_mean_burst) if not isnan(y))
        else:
            min_index_var = 0

        if min_index == None:
            min_index = min_index_var
        else:
            min_index = min(min_index, min_index_var)

    # remove the first common NaN to all variables
    for var in burst_vars.keys():
        for product in burst_vars[var].keys():
            burst_vars[var][product] = burst_vars[var][product][min_index:-1]

    # look for last non NaN. we just have to reverse the list
    max_non_nan_idx = None
    for var in burst_vars.keys():
        var_mean_burst       = burst_vars[var]['var_mean'] # first non TIME product
        var_mean_burst       = pd.Series(var_mean_burst) # create a pandas series to find easily last non nan index
        max_last_non_nan_var = var_mean_burst.last_valid_index()
        if max_non_nan_idx == None:
            max_non_nan_idx = max_last_non_nan_var
        else:
            max_non_nan_idx = max(max_non_nan_idx, max_last_non_nan_var)

    # remove the last common NaN to all variables
    if max_non_nan_idx is not None:
        for var in burst_vars.keys():
            for product in burst_vars[var].keys():
                burst_vars[var][product] = burst_vars[var][product][:max_non_nan_idx]

    return burst_vars

def get_time_val(netcdf_file_obj):
    """
    return the TIME numeric values from a NetCDF file
    """
    return netcdf_file_obj.variables['TIME'][:]

def get_var_val_var_qc_exclusion(netcdf_file_obj, varname, qc_flag):
    """
    for a qc flag values [0:9], returns the var_values array, and var_qc_flag_exclusion
    which is a boolean array returning True for all qc >= qc_flag

    Also exlude all TIME values outside of deployment range as defined in gatts
    """
    var_values            = netcdf_file_obj.variables[varname][:]
    var_qc_flag_exclusion = netcdf_file_obj.variables['%s_quality_control' % varname][:] >= qc_flag

    # we exclude as well ALL TIMES before date_deployment_start, and after
    # date_deployment_end
    time                  = netcdf_file_obj.variables['TIME']
    date_deployment_start = date2num(datetime.strptime(netcdf_file_obj.time_deployment_start, '%Y-%m-%dT%H:%M:%SZ'), time.units, time.calendar)
    date_deployment_end   = date2num(datetime.strptime(netcdf_file_obj.time_deployment_end, '%Y-%m-%dT%H:%M:%SZ'), time.units, time.calendar)

    time_before = date_deployment_start >= time[:]
    time_after  = date_deployment_end <= time[:]

    var_qc_flag_exclusion = [a or b for a, b in zip(time_before, var_qc_flag_exclusion)]
    var_qc_flag_exclusion = [a or b for a, b in zip(time_after, var_qc_flag_exclusion)]

    return var_values, var_qc_flag_exclusion

def list_var_to_average(netcdf_file_obj):
    """
    return a list of variable to create a burst average for
    """
    var_list = netcdf_file_obj.variables.keys()
    var_list = [x for x in var_list if not x.endswith('_quality_control')]

    var_to_remove = []
    for varname in var_list:
        if 'TIME' not in netcdf_file_obj.variables[varname].dimensions:
            var_to_remove.append(varname)

    var_to_remove.extend(('TIME', 'VOLT', 'SSPD', 'CNDC'))
    var_list = [x for x in var_list if x not in var_to_remove]

    return var_list

def list_dimensionless_var(netcdf_file_obj):
    var_list    = netcdf_file_obj.variables.keys()
    dimless_var = []
    for varname in var_list:
        if len(netcdf_file_obj.variables[varname].dimensions) == 0:
            dimless_var.append(varname)
    return dimless_var

def burst_average_data(time_values, var_values, var_qc_exclusion):
    """
    create burst average data for var_values. This is the core of the script
    """
    n_seconds_day = 24 * 3600
    difft         = np.round(np.diff(time_values) * n_seconds_day) # this gives us a spike for each new burst
    fill_value    = float('nan')

    # look for start index of each burst, ie the index of each new spike of
    # difft variable
    idx_spike = [0] # initialise first index
    spikes    = np.where(difft > 1)[0] + 1
    idx_spike.extend(spikes)

    # initialise arrays
    time_mean_burst   = []
    var_mean_burst    = []
    var_min_burst     = []
    var_max_burst     = []
    var_sd_burst      = []
    var_num_obs_burst = []

    for idx_spike_idx, idx_spike_val in enumerate(idx_spike[:-1]):
        index_burst_range = range(idx_spike_val, idx_spike[idx_spike_idx + 1])

        # burst average of TIME variable. All the range of the burst is used
        time_mean_burst.append((time_values[index_burst_range[0]] + time_values[index_burst_range[-1]]) / 2)

        # For NON TIME variables, the operations are only performed in respect
        # to boolean values found in var_qc_exclusion variable.
        # this var_qc_exclusion variable is set to True for all IMOS IODE flags
        # greater than a specific value
        valid_index_burst_range = [val for val in index_burst_range if not var_qc_exclusion[val]]

        # condition in case no good qc data was found for one burst
        if valid_index_burst_range:
            var_mean_burst   .append(np.mean(var_values[valid_index_burst_range]))
            var_min_burst    .append(np.min(var_values[valid_index_burst_range]))
            var_max_burst    .append(np.max(var_values[valid_index_burst_range]))
            var_sd_burst     .append(np.std(var_values[valid_index_burst_range]))
            var_num_obs_burst.append(len(valid_index_burst_range))
        else:
            var_mean_burst   .append(fill_value)
            var_min_burst    .append(fill_value)
            var_max_burst    .append(fill_value)
            var_sd_burst     .append(fill_value)
            var_num_obs_burst.append(0)

    burst_var = {'time_mean':   time_mean_burst,
                 'var_mean':    var_mean_burst,
                 'var_min':     var_min_burst,
                 'var_max':     var_max_burst,
                 'var_sd':      var_max_burst,
                 'var_num_obs': var_num_obs_burst}

    return burst_var

def generate_netcdf_burst_filename(input_netcdf_file_path, burst_vars):
    """
    generate the filename of a burst average netcdf for both CTD and WQM
    """
    netcdf_file_obj   = Dataset(input_netcdf_file_path, 'r')
    site_code         = netcdf_file_obj.site_code
    input_netcdf_name = os.path.basename(input_netcdf_file_path)
    pattern           = re.compile("^(IMOS_.*)_([0-9]{8}T[0-9]{6}Z)_(.*)_(FV0[0-9])_(.*)_END")
    match_group       = pattern.match(input_netcdf_name)

    time_burst_vals = burst_vars['TEMP']['time_mean']
    time_min        = num2date(time_burst_vals, netcdf_file_obj['TIME'].units, netcdf_file_obj['TIME'].calendar).min().strftime('%Y%m%dT%H%M%SZ')
    time_max        = num2date(time_burst_vals, netcdf_file_obj['TIME'].units, netcdf_file_obj['TIME'].calendar).max().strftime('%Y%m%dT%H%M%SZ')
    burst_filename  = "%s_%s_%s_FV02_%s-burst-averaged_END-%s_C-%s.nc" % (match_group.group(1), time_min, \
                                                                          site_code, match_group.group(5), \
                                                                          time_max, datetime.now().strftime("%Y%m%dT%H%M%SZ"))
    netcdf_file_obj.close()
    return burst_filename

def create_burst_average_netcdf(input_netcdf_file_path, output_dir):
    """
    generate the burst netcdf file for WQM product.
    see variable conf_file if editing of gatt and var att need to be done
    """
    input_file_rel_path = get_input_file_rel_path(input_netcdf_file_path)
    input_netcdf_obj    = Dataset(input_netcdf_file_path, 'r')
    burst_vars          = create_burst_average_var(input_netcdf_obj)
    time_burst_vals     = burst_vars['TEMP']['time_mean']
    tmp_netcdf_dir      = tempfile.mkdtemp()

    output_netcdf_file_path = os.path.join(tmp_netcdf_dir, generate_netcdf_burst_filename(input_netcdf_file_path, burst_vars))
    output_netcdf_obj       = Dataset(output_netcdf_file_path, "w", format="NETCDF4")

    # read gatts from input, add them to output. Some gatts will be overwritten
    input_gatts     = input_netcdf_obj.__dict__.keys()
    gatt_to_dispose = ['author', 'file_version_quality_control', 'quality_control_set',
                       'compliance_checker_version', 'compliance_checker_last_updated']

    for gatt in input_gatts:
        if gatt not in gatt_to_dispose:
            setattr(output_netcdf_obj, gatt, getattr(input_netcdf_obj, gatt))

    if 'WQM' in output_netcdf_obj.instrument:
        output_netcdf_obj.title = 'Burst-averaged biogeochemical measurements at %s' % (input_netcdf_obj.site_code)
    elif 'CTD' in output_netcdf_obj.instrument:
        output_netcdf_obj.title = 'Burst-averaged moored CTD measurements at %s' % (input_netcdf_obj.site_code)

    output_netcdf_obj.input_file   = input_file_rel_path
    output_netcdf_obj.date_created = datetime.now().strftime("%Y-%m-%dT%H:%M:%SZ")

    depth_burst_mean_val = burst_vars['DEPTH']['var_mean']
    output_netcdf_obj.geospatial_vertical_min = (np.ma.masked_array(depth_burst_mean_val, np.isnan(depth_burst_mean_val))).min()
    output_netcdf_obj.geospatial_vertical_max = (np.ma.masked_array(depth_burst_mean_val, np.isnan(depth_burst_mean_val))).max()

    # set up dimensions and variables
    output_netcdf_obj.createDimension("TIME", len(time_burst_vals))
    var_time = output_netcdf_obj.createVariable("TIME", input_netcdf_obj["TIME"].dtype,
                                                ("TIME",), fill_value=get_imos_parameter_info('TIME', '_FillValue'))

    dimensionless_var = list_dimensionless_var(input_netcdf_obj)
    for var in dimensionless_var:
        output_netcdf_obj.createVariable(var, input_netcdf_obj[var].dtype, ())
        output_netcdf_obj[var][:] = input_netcdf_obj[var][:]

    for var in burst_vars.keys():
        fillvalue = get_imos_parameter_info(var, '_FillValue')
        if fillvalue == []:
            fillvalue = 999999.0

        output_var_mean    = output_netcdf_obj.createVariable(var, "f4", ("TIME",), fill_value=fillvalue)
        output_var_min     = output_netcdf_obj.createVariable('%s_burst_min' % var, "f4", ("TIME",), fill_value=fillvalue)
        output_var_max     = output_netcdf_obj.createVariable('%s_burst_max' % var, "f4", ("TIME",), fill_value=fillvalue)
        output_var_sd      = output_netcdf_obj.createVariable('%s_burst_sd' % var, "f4", ("TIME",), fill_value=fillvalue)
        output_var_num_obs = output_netcdf_obj.createVariable('%s_num_obs' % var, "i4", ("TIME",), fill_value=fillvalue)

        # set up 'bonus' var att from original FV01 file into FV02
        input_var_object   = input_netcdf_obj[var]
        input_var_list_att = input_var_object.__dict__.keys()
        var_att_disposable = ['name', 'long_name', \
                              '_FillValue', 'ancillary_variables', \
                              'ChunkSize', 'coordinates']
        for var_att in [att for att in input_var_list_att if att not in var_att_disposable]:
            setattr(output_netcdf_obj[var], var_att, getattr(input_netcdf_obj[var], var_att))
            if var_att != 'comment':
                setattr(output_var_min, var_att, getattr(input_netcdf_obj[var], var_att))
                setattr(output_var_max, var_att, getattr(input_netcdf_obj[var], var_att))
                setattr(output_var_sd, var_att, getattr(input_netcdf_obj[var], var_att))

        setattr(output_var_mean, 'coordinates', getattr(input_netcdf_obj[var], 'coordinates', ''))
        setattr(output_var_mean, 'ancillary_variables', ('%s_num_obs %s_burst_sd %s_burst_min %s_burst_max' % (var, var, var, var)))

        setattr(output_var_mean, 'cell_methods', 'TIME: mean')
        setattr(output_var_min, 'cell_methods', 'TIME: min')
        setattr(output_var_max, 'cell_methods', 'TIME: max')
        setattr(output_var_sd, 'cell_methods', 'TIME: standard_deviation')

        setattr(output_var_sd, 'long_name', 'Standard deviation of values in burst, after rejection of flagged data')
        setattr(output_var_num_obs, 'long_name', 'Number of observations included in the averaging process')
        setattr(output_var_min, 'long_name', 'Minimum data value in burst, after rejection of flagged data')
        setattr(output_var_max, 'long_name', 'Maximum data value in burst, after rejection of flagged data')
        setattr(output_var_mean, 'long_name', 'Mean of %s values in burst, after rejection of flagged data' % (getattr(input_netcdf_obj[var], 'standard_name',
                                                                                                                       getattr(input_netcdf_obj[var], 'long_name', ''))))

        output_var_num_obs.units = "1"
        var_units = getattr(input_netcdf_obj[var], 'units')
        if var_units:
            output_var_mean.units = var_units
            output_var_min.units  = var_units
            output_var_max.units  = var_units
            output_var_sd.units   = var_units

        var_stdname = getattr(input_netcdf_obj[var], 'standard_name', '')
        if var_stdname != '':
            output_var_num_obs.standard_name = "%s number_of_observations" % var_stdname

        # set up var values
        output_var_mean[:]    = np.ma.masked_invalid(burst_vars[var]['var_mean'])
        output_var_min[:]     = np.ma.masked_invalid(burst_vars[var]['var_min'])
        output_var_max[:]     = np.ma.masked_invalid(burst_vars[var]['var_max'])
        output_var_sd[:]      = np.ma.masked_invalid(burst_vars[var]['var_sd'])
        output_var_num_obs[:] = np.ma.masked_invalid(burst_vars[var]['var_num_obs'])

    # add gatts and variable attributes as stored in config files
    conf_file_generic = os.path.join(os.path.dirname(__file__), 'generate_nc_file_att')
    generate_netcdf_att(output_netcdf_obj, conf_file_generic, conf_file_point_of_truth=True)

    # set up original varatts for the following dim, var
    varnames = dimensionless_var
    varnames.append('TIME')
    for varname in varnames:
        for varatt in input_netcdf_obj[varname].__dict__.keys():
            setattr(output_netcdf_obj[varname], varatt, getattr(input_netcdf_obj[varname], varatt))
    time_comment = '%s. Time stamp corresponds to the middle of the burst measurement which lasts %s seconds.' % (getattr(input_netcdf_obj['TIME'], 'comment', ''),
                                                                                                                 input_netcdf_obj.instrument_burst_duration)
    output_netcdf_obj.variables['TIME'].comment = time_comment.lstrip('. ')

    time_burst_val_dateobj = num2date(time_burst_vals, input_netcdf_obj['TIME'].units, input_netcdf_obj['TIME'].calendar)
    output_netcdf_obj.time_coverage_start = time_burst_val_dateobj.min().strftime('%Y-%m-%dT%H:%M:%SZ')
    output_netcdf_obj.time_coverage_end   = time_burst_val_dateobj.max().strftime('%Y-%m-%dT%H:%M:%SZ')

    # append original gatt to burst average gatt
    gatt = 'comment'
    setattr(output_netcdf_obj, gatt, ('%s. %s' % (getattr(input_netcdf_obj, gatt, ''), getattr(output_netcdf_obj, gatt) )).lstrip('. '))

    gatt = 'history'
    setattr(output_netcdf_obj, gatt, ('%s. %s' % (getattr(input_netcdf_obj, gatt, ''), 'Created %s' % time.ctime(time.time()))).lstrip('. '))

    gatt = 'abstract'
    setattr(output_netcdf_obj, gatt, ('%s. %s' % (getattr(output_netcdf_obj, gatt, ''), \
                                                 'Data from the bursts have been cleaned and averaged to create data products. This file is one such product.')).lstrip('. '))

    # add burst keywords
    gatt           = 'keywords'
    keywords_burst = 'AVERAGED, BINNED'
    setattr(output_netcdf_obj, gatt, ('%s, %s' % (getattr(input_netcdf_obj, gatt, ''), keywords_burst)).lstrip(', '))

    # add values to variables
    output_netcdf_obj['TIME'][:]          = np.ma.masked_invalid(time_burst_vals)

    product_processing_description = inspect.getfile(inspect.currentframe())
    script_dir_path = os.path.dirname(os.path.abspath(inspect.getfile(inspect.currentframe())))
    product_processing_description = os.path.join(script_dir_path[script_dir_path.index('data-services') + len('data-services') + 1:], os.path.basename(product_processing_description))
    output_netcdf_obj.product_processing_description = 'Product created by www.github.com/aodn/data-services/tree/master/%s' % product_processing_description

    output_netcdf_obj.close()
    input_netcdf_obj.close()

    shutil.move(output_netcdf_file_path, output_dir)
    shutil.rmtree(tmp_netcdf_dir)
    return os.path.join(output_dir, os.path.basename(output_netcdf_file_path))

def args():
    parser = argparse.ArgumentParser()
    parser.add_argument("input_fv01_netcdf_path", type=str, help="path to CTD or WQM FV01 netcdf file")
    parser.add_argument("output_dir", type=str, help="output directory of FV02 netcdf file")
    vargs = parser.parse_args()

    if not os.path.exists(vargs.input_fv01_netcdf_path):
        msg = '%s not a valid path' % vargs.input_netcdf_file_path
        print >> sys.stderr, msg
        sys.exit(1)
    elif not os.path.exists(vargs.output_dir):
        msg = '%s not a valid path' % vargs.output_dir
        print >> sys.stderr, msg
        sys.exit(1)

    return vargs


if __name__ == "__main__":
    vargs           = args()
    burst_file_path = create_burst_average_netcdf(vargs.input_fv01_netcdf_path, vargs.output_dir)
    print burst_file_path
