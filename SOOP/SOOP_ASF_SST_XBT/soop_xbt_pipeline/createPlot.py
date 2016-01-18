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

    netcdfFileObj       = Dataset(netcdfFilePath, 'r', format='NETCDF4')
    cruiseId            = netcdfFileObj.XBT_cruise_ID
    seaWaterTemperature = netcdfFileObj.variables['TEMP']
    depth               = netcdfFileObj.variables['DEPTH']
    time                = netcdfFileObj.variables['TIME']
    time                = num2date(time[:], time.units, time.calendar)
    lat                 = netcdfFileObj.variables['LATITUDE'][:]
    lon                 = netcdfFileObj.variables['LONGITUDE'][:]
    xbtUniqueId         = netcdfFileObj.XBT_uniqueid

    # load only the data which does not have a quality control value equal to qcFlag and greater than goodFlag
    badFlag       = 4
    goodFlag      = 1
    indexGoodData = (netcdfFileObj.variables['TEMP_quality_control'][:] != badFlag) & (netcdfFileObj.variables['TEMP_quality_control'][:] >= goodFlag)
    tempValues    = seaWaterTemperature[:]
    depthValues   = depth[:]

    # modify the values which we don't want to plot to replace them with the Fillvalue
    tempValues[~indexGoodData]    = seaWaterTemperature._FillValue
    indexGoodData1D               = list(itertools.chain(*indexGoodData)) == True
    depthValues[~indexGoodData1D] = depth._FillValue

    # modify the mask in order to change the boolean, since some previous non Fillvalue data are now Fillvalue
    tempValues  = ma.masked_values(tempValues, netcdfFileObj.variables['TEMP']._FillValue)
    depthValues = ma.masked_values(depthValues, netcdfFileObj.variables['DEPTH']._FillValue)

    fig, ax1 = plt.subplots(figsize=(13,9.2), dpi=80, facecolor='w', edgecolor='k')
    fig.canvas.set_window_title('A Boxplot Example')
    plt.subplots_adjust(left=0.075, right=0.95, top=0.9, bottom=0.25)

    ax1.set_xlabel(seaWaterTemperature.long_name + ' in ' + seaWaterTemperature.units)
    ax1.set_ylabel(depth.long_name + ' in ' + depth.units)

    try:
        if all(tempValues.mask):
            plt.text(0.5, 0.5, 'No Good Data available', color='r',
                fontsize=20,
                horizontalalignment='center',
                verticalalignment='center',
                transform=ax1.transAxes,
            )
        else:
            plot (tempValues[:],-depthValues[:])
    except:
        plot (tempValues[:],-depthValues[:])

    ax1.set_ylim(-1100,0)
    xticks([-3, 0, 5, 10, 15, 20, 25, 30, 35])

    dateStart = datetime.datetime.strptime(netcdfFileObj.time_coverage_start, "%Y-%m-%dT%H:%M:%SZ").strftime("%Y-%m-%d %H:%M:%S UTC")
    title(netcdfFileObj.title + '\n Cruise  ' + cruiseId + '-' + netcdfFileObj.XBT_line_description + ' - XBT id ' + str(xbtUniqueId) + '\nlocation ' + "%0.2f" % lat + ' S ; ' + "%0.2f" % lon + ' E\n' + dateStart, fontsize=10)

    netcdfFileObj.close()
    jpgOutput = tempfile.NamedTemporaryFile(delete=False)
    matplotlib.pyplot.savefig(jpgOutput)
    return jpgOutput.name

if __name__== '__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit_cleanup(1)

    jpgOutput = create_plot(sys.argv[1])

    if not jpgOutput:
        exit_cleanup(1)

    print jpgOutput
    exit_cleanup(0)
