#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# Author: Laurent Besnard
# Institute: IMOS / eMII
# email address: laurent.besnard@utas.edu.au

import datetime
import itertools
import sys
import tempfile

from matplotlib.pyplot import (plot, savefig, subplots, subplots_adjust, text,
                               title, xticks)
from netCDF4 import Dataset, num2date
from numpy import ma


def create_plot(netcdfFilePath):
    """ create plot to be ingested in SOOP XBT NRT pipeline"""
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
    temp_values[~i_good_data] = sea_water_temperature._FillValue
    indexGoodData1D           = list(itertools.chain(*i_good_data)) == True

    # new XBT files dont have a FillValue att for DEPTH since DEPTH is a
    # dimension. However previous files do. Need to handle both case if we do
    # some reprocessing
    if hasattr(depth, '_FillValue'):
        depth_values[~indexGoodData1D] = depth._FillValue
        depth_values = ma.masked_values(depth_values, F.variables['DEPTH']._FillValue)

    # Modify the mask in order to change the boolean, since some previous non Fillvalue data are now Fillvalue
    temp_values  = ma.masked_values(temp_values, F.variables['TEMP']._FillValue)

    fig, ax1 = subplots(figsize=(13, 9.2), dpi=80, facecolor='w', edgecolor='k')
    subplots_adjust(left=0.075, right=0.95, top=0.9, bottom=0.25)

    ax1.set_xlabel(sea_water_temperature.long_name + ' in ' + sea_water_temperature.units)
    ax1.set_ylabel(depth.long_name + ' in ' + depth.units)

    try:
        if all(temp_values.mask):
            text(0.5, 0.5, 'No Good Data available', color='r',
                 fontsize=20,
                 horizontalalignment='center',
                 verticalalignment='center',
                 transform=ax1.transAxes)
        else:
            plot(temp_values[:], -depth_values[:])
    except:
        plot(temp_values[:], -depth_values[:])

    ax1.set_ylim(-1100, 0)
    xticks([-3, 0, 5, 10, 15, 20, 25, 30, 35])

    date_start = datetime.datetime.strptime(F.time_coverage_start, "%Y-%m-%dT%H:%M:%SZ").strftime("%Y-%m-%d %H:%M:%S UTC")
    title(F.title + '\n Cruise  ' + cruise_id + '-' + F.XBT_line_description +
          ' - XBT id ' + str(xbt_unique_id) + '\nlocation ' + "%0.2f" % lat +
          ' S ; ' + "%0.2f" % lon + ' E\n' + date_start, fontsize=10)

    F.close()
    jpg_output = tempfile.NamedTemporaryFile(delete=False)
    savefig(jpg_output)
    return jpg_output.name


if __name__ == '__main__':
    # Read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    jpg_output = create_plot(sys.argv[1])

    if not jpg_output:
        exit(1)

    print jpg_output
    exit(0)
