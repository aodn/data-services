#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# Author: Laurent Besnard
# Institute: IMOS / eMII
# email address: laurent.besnard@utas.edu.au

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
from numpy import ma
from netCDF4 import Dataset, num2date
from matplotlib.pyplot import (figure, plot, xlabel, ylabel, title, show, xticks)
import matplotlib.pyplot as plt
import pylab
import itertools

def exit_cleanup(retval):
    shutil.rmtree(MPLCONFIGDIR)
    exit(retval)

def create_plot(netcdfFilePath):

    F                     = Dataset(netcdfFilePath, 'r', format='NETCDF4')
    cruise_id             = F.XBT_cruise_ID
    sea_water_temperature = F.variables['TEMP']
    depth                 = F.variables['DEPTH']
    time                  = F.variables['TIME']
    time                  = num2date(time[:], time.units, time.calendar)
    lat                   = F.variables['LATITUDE'][:]
    lon                   = F.variables['LONGITUDE'][:]
    xbt_unique_id         = F.XBT_uniqueid

    # Load only the data which does not have a quality control value equal to qcFlag and greater than good_flag
    bad_flag       = 4
    good_flag      = 1
    i_good_data    = (F.variables['TEMP_quality_control'][:] != bad_flag) & (F.variables['TEMP_quality_control'][:] >= good_flag)
    temp_values    = sea_water_temperature[:]
    depth_values   = depth[:]

    # Modify the values which we don't want to plot to replace them with the Fillvalue
    temp_values[~i_good_data]      = sea_water_temperature._FillValue
    indexGoodData1D                = list(itertools.chain(*i_good_data)) == True
    depth_values[~indexGoodData1D] = depth._FillValue

    # Modify the mask in order to change the boolean, since some previous non Fillvalue data are now Fillvalue
    temp_values  = ma.masked_values(temp_values, F.variables['TEMP']._FillValue)
    depth_values = ma.masked_values(depth_values, F.variables['DEPTH']._FillValue)

    fig, ax1 = plt.subplots(figsize=(13,9.2), dpi=80, facecolor='w', edgecolor='k')
    fig.canvas.set_window_title('A Boxplot Example')
    plt.subplots_adjust(left=0.075, right=0.95, top=0.9, bottom=0.25)

    ax1.set_xlabel(sea_water_temperature.long_name + ' in ' + sea_water_temperature.units)
    ax1.set_ylabel(depth.long_name + ' in ' + depth.units)

    try:
        if all(temp_values.mask):
            plt.text(0.5, 0.5, 'No Good Data available', color='r',
                fontsize=20,
                horizontalalignment='center',
                verticalalignment='center',
                transform=ax1.transAxes,
            )
        else:
            plot(temp_values[:], -depth_values[:])
    except:
        plot(temp_values[:], -depth_values[:])

    ax1.set_ylim(-1100, 0)
    xticks([-3, 0, 5, 10, 15, 20, 25, 30, 35])

    date_start = datetime.datetime.strptime(F.time_coverage_start, "%Y-%m-%dT%H:%M:%SZ").strftime("%Y-%m-%d %H:%M:%S UTC")
    title(F.title + '\n Cruise  ' + cruise_id + '-' + F.XBT_line_description + ' - XBT id ' + str(xbt_unique_id) + '\nlocation ' + "%0.2f" % lat + ' S ; ' + "%0.2f" % lon + ' E\n' + date_start, fontsize=10)

    F.close()
    jpg_output = tempfile.NamedTemporaryFile(delete=False)
    matplotlib.pyplot.savefig(jpg_output)
    return jpg_output.name

if __name__== '__main__':
    # Read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit_cleanup(1)

    jpg_output = create_plot(sys.argv[1])

    if not jpg_output:
        exit_cleanup(1)

    print jpg_output
    exit_cleanup(0)
