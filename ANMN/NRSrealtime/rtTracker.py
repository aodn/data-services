#! /usr/bin/env python
#
# Python module to process real-time Tracker data from ANMN NRS moorings.


import numpy as np
from dataUtils import readCSV, timeFromString
import IMOSnetCDF as inc
from datetime import datetime
from math import pi


### module variables ###################################################

i = np.int32
i2 = np.int64
f = np.float64
formTracker = np.dtype( 
    [('ID',  i2),
     ('Status', i),
     ('Time',  'S24'),
     ('Latitude',  f),
     ('Longitude', f)]
    )


### functions #######################################################

def readTracker(start_date=None, end_date=None, csvFile='Tracker.csv'):
    """
    Read data from a Tracker.csv file (in current directory, unless
    otherwise specified) and return as an ndarray.
    """

    # read in Tracker file
    data = readCSV(csvFile, formTracker)

    # Filter out bad data (status=0)
    ii = np.where(stat == 1)[0]
    data = data[ii]

    # convert time from string to something more numeric 
    # (using default epoch in netCDF module)
    (time, dtime) = timeFromString(data['Time'], inc.epoch)

    # select time range
    ii = np.arange(len(dtime))
    if end_date:
        ii = np.where(dtime < end_date)[0]
    if start_date:
        ii = np.where(dtime[ii] > start_date)[0]
    if len(ii) < 1:
        print csvFile+': No data in given time range!'
        return
    data = data[ii]
    time = time[ii]
    dtime = dtime[ii]

    return data, time, dtime


def xyTracker(data):
    "Convert lat/lon to (x, y) offsets in metres from median position."

    lat = data['Latitude']
    lon = data['Longitude']

    LAT = np.median(lat) * pi/180.
    la = (lat-lat.median())* pi/180.
    lo = (lon-np.median(lon))* pi/180.

    r = 6400000.  # Raius of Earth in metres
    x = r * lo * cos(LAT)
    y = r * la

    return x, y
