#!/usr/bin/env python
# -*- coding: utf-8 -*-
# B. Pasquer Jan
# Script that generates timeseries plot of data along transect between Devonport and Port Melbourne\
# 2 plots are generated :  (1) Time vs Temperature & Salinity (2) Time vs Chlorophyll & Turbidity

import sys, os
import tempfile
import shutil

# the next 3 lines are needed to create plots without a xserver
MPLCONFIGDIR = tempfile.mkdtemp()
os.environ['MPLCONFIGDIR'] = MPLCONFIGDIR
import matplotlib
matplotlib.use('Agg') # because no Xserver. has to be run after import before pylab

import string
import datetime
import re
import numpy as np
from numpy import ma
from netCDF4 import Dataset, num2date
from matplotlib.pyplot import (figure, plot, xlabel, ylabel, title, show, xticks)
import matplotlib.pyplot as plt
import pylab
from math import radians, cos, sin, asin, sqrt
import pyproj
import time

def exit_cleanup(retval):
    shutil.rmtree(MPLCONFIGDIR)
    exit(retval)

def axis_positions():
    return [
        [ 0,    -0.08, 'Melbourne'       ],
        [ 0.18, -0.08, 'Port Philip Bay' ],
        [ 0.55, -0.08, 'Bass Strait'     ],
        [ 1,    -0.08, 'Devonport'       ],
    ]

# get all the element forming a netcdf file name
def get_file_parts(nc_file):
    return os.path.basename(nc_file).split("_")

def is_iteratable(value):
    return hasattr(value, '__iter__')

def add_png_extension(nc_file):
    name = os.path.basename(nc_file).split(".")[0]
    ext = '.png'
    name = '%s%s' % (name, ext)
    return name

def get_var_info():
    """
    Define variable information
    """
    return {
        'TEMP' : [ 'Sea Surface Temperature', 'Degrees Celsius', 'temperature' ],
        'PSAL' : [ 'Seawater Salinity',       '1e-3',            'salinity'    ],
        'TURB' : [ 'Turbidity',               'NTU',             'turbidity'   ],
        'CPHL' : [ 'Chlorophyll',             'ug l-1',          'chlorophyll' ],
    }

def get_transect():
    """
    Define full transect name
    """
    return {
            'D2M' : 'Devonport - Melbourne',
            'M2D' : 'Melbourne - Devonport'
    }

def set_yaxis_properties(param, values):
    """
    Define parameter specific y axis properties
    """
    if param == 'TEMP':
        miny = np.fix(ma.min(values))
        maxy = miny + 8
        tick_spacing = 1

    elif param == 'PSAL':
    # range  somewhat arbitrary even if values can go outside the range
        if ma.max(values) < 36.8:
            miny = 33
            maxy = 37
        else:
            miny = 33.5
            maxy = 37.5
        tick_spacing = .5

    elif param == 'CPHL':
        miny = 0
        maxy = 1.6
        tick_spacing = .4

    else: # param =='TURB'
        miny = 0
        maxy = 8
        tick_spacing = 2

    return miny, maxy, tick_spacing

def compute_distance(lon, lat, transect):

    port_mel_lon = 144.93
    port_mel_lat = -37.85
    devonport_jetty_lon = 146.36388889
    devonport_jetty_lat = -41.177777
    p = pyproj.Proj(proj='utm', zone=55, ellps='WGS84')

    dist = 0 ; j = 0
    distance = ([])
    for i in range(len(lon)):
        if j == 0 and transect == 'D2M':
            x1,y1 = p(devonport_jetty_lon, devonport_jetty_lat)
            j += 1
        elif j == 0 and transect == 'M2D':
            x1,y1 = p(port_mel_lon, port_mel_lat)
            j += 1
        else:
            x1,y1 = p(lon[i-1], lat[i-1])

        x2,y2 = p(lon[i], lat[i])
        dist += sqrt((x2 - x1)** 2 +(y2 -y1)** 2)/1000
        distance.append(dist)

    if transect == 'D2M':
        distance = 433 - np.asarray(distance)
    return distance


def create_plot_transect(netcdf_file_path, tmp_dir, param1, param2, transect):
    """
    Function plotting timeseries of 2 variable along a transect
    Inputs:
        - param1 : 'TEMP' or 'CPHL' (Temperature, Chlorophyll)
        - param2 : 'PSAL' or 'TURB (Salinity, Turbidity)
        - transect :'D2M' or 'M2D'
    """

    netcdf_file_obj = Dataset(netcdf_file_path, 'r', format='NETCDF4')
    time  = netcdf_file_obj.variables['TIME']
    time = num2date(time[:], time.units, time.calendar)
    lat = netcdf_file_obj.variables['LATITUDE'][:]
    lon = netcdf_file_obj.variables['LONGITUDE'][:]
    p1 = netcdf_file_obj.variables[param1]
    p2 = netcdf_file_obj.variables[param2]
    # mask data where lat or lon sert to fillvalue
    
    # plot only data with QC flag =1 ,2 (good data, probably good data)
    no_qc = 0
    good_flag = [1, 2]

    good_p1_idx = (netcdf_file_obj.variables[param1 + '_quality_control'][:] != no_qc ) & \
        (netcdf_file_obj.variables[param1 + '_quality_control'][:] <= good_flag[1])
    good_p2_idx = (netcdf_file_obj.variables[param2 + '_quality_control'][:] != no_qc ) & \
        (netcdf_file_obj.variables[param2 + '_quality_control'][:] <= good_flag[1])

    p1_values = p1[:]
    p2_values = p2[:]

    # replace unwanted "bad" values with the Fillvalue
    p1_values[~good_p1_idx] = p1._FillValue
    p2_values[~good_p2_idx] = p2._FillValue

    # modify the mask in order to change the boolean, since some previous non Fillvalue data are now Fillvalue
    p1_values  = ma.masked_values(p1_values, netcdf_file_obj.variables[param1]._FillValue)
    p2_values = ma.masked_values(p2_values, netcdf_file_obj.variables[param2]._FillValue)

    # compute distance from Port Melbourne using great circle method
    distance = compute_distance(lon, lat, transect)

    fig, ax1 = plt.subplots(figsize=(13,9.2), dpi=80, facecolor='w', edgecolor='k')
    plt.subplots_adjust(left=0.075, right=0.95, top=0.9, bottom=0.25)

    # set proprties for the first axe
    ax1.set_xlabel('Distance in km')
    ax1.set_xlim(0, 440)
    ax1.set_xticks(np.arange(0, 450, 40))
    ax1.set_ylabel(get_var_info()[param1][0] + ' (' + get_var_info()[param1][1] + ')', color='b')
    # yaxis proporties are automatically adjusted . Properties depend on the plotted parameter
    (miny1, maxy1, tick_spacing1) = set_yaxis_properties(param1, p1_values)
    ax1.set_ylim(miny1, maxy1)
    ax1.set_yticks(np.arange(miny1, maxy1 + .1, tick_spacing1))
    # Make the y-axis label and tick labels match the line color
    for tl in ax1.get_yticklabels():
        tl.set_color('b')

    # second axe
    ax2 = ax1.twinx()
    ax2.set_xlim(0, 440)
    ax2.set_xticks(np.arange(0, 480, 40))
    ax2.set_ylabel(get_var_info()[param2][0] + ' (' + get_var_info()[param2][1] + ')', color='r')
    (miny2, maxy2, tick_spacing2) = set_yaxis_properties(param2, p2_values)
    ax2.set_ylim(miny2, maxy2)
    ax2.set_yticks(np.arange(miny2, maxy2 +.1, tick_spacing2))
    for tl in ax2.get_yticklabels():
        tl.set_color('r')

    if is_iteratable(p1_values.mask) and all(p1_values.mask):
        plt.text(0.5, 0.5, 'No Good Data available', color='r',
            fontsize=20,
            horizontalalignment='center',
            verticalalignment='center',
            transform=ax1.transAxes,
        )
    else:
        ax1.plot(distance,p1_values[:], 'b-')
        ax2.plot(distance,p2_values[:], 'r-')

        for axis_position_tuple in axis_positions():
            plt.text(
                axis_position_tuple[0],
                axis_position_tuple[1],
                axis_position_tuple[2],
                fontsize=15,
                horizontalalignment='center',
                verticalalignment='center',
                transform=ax1.transAxes,
            )

    date_start = datetime.datetime.strptime(netcdf_file_obj.time_coverage_start, "%Y-%m-%dT%H:%M:%SZ").strftime("%d-%b-%Y")
    full_title = "%s and %s during a transect %s on the %s" % (get_var_info()[param1][0], get_var_info()[param2][0], get_transect()[transect], date_start)
    title(full_title, fontsize=13)

    # generate file name and save
    product_name = 'transect-%s-%s-%s' % (transect, get_var_info()[param1][2], get_var_info()[param2][2])
    png_output = re.sub('transect-%s' % transect, product_name, os.path.basename(netcdf_file_path))
    png_output = add_png_extension(png_output)

    png_output = os.path.join(tmp_dir, png_output)
    matplotlib.pyplot.savefig(png_output)
    netcdf_file_obj.close()

    return png_output

if __name__== '__main__':
    # read filename from command line
    if len(sys.argv) < 3:
        print >>sys.stderr, "Usage: %s NETCDF_FILE TEMPORARY_OUTPUT_DIR" % sys.argv[0]
        exit_cleanup(1)

    nc_file = sys.argv[1]
    tmp_dir = sys.argv[2]
    transect = get_file_parts(nc_file)[6][-3:]
    png_output_ts = create_plot_transect(nc_file, tmp_dir, 'TEMP', 'PSAL', transect)
    png_output_ct = create_plot_transect(nc_file, tmp_dir, 'CPHL', 'TURB', transect)

    if (not png_output_ts or not png_output_ct):
        exit_cleanup(1)

    exit_cleanup(0)
