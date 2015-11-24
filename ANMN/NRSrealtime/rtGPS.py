#! /usr/bin/env python
#
# Python module to process real-time GPS data from ANMN NRS moorings.


import numpy as np
from dataUtils import readCSV, timeFromString
import IMOSnetCDF as inc
from datetime import datetime


### module variables ###################################################

i = np.int32
f = np.float64
formGPS = np.dtype( 
    [('Config ID',  i),
     ('Trans ID', i),
     ('Record', i),
     ('Header Index', i),
     ('Time',  'S24'),
     ('Latitude',  f),
     ('Longitude', f)]
     ('No Satellites', i),
     ('Fix Quality', i),
     ('HDOP', i),
    )


### functions #######################################################

def readGPS(start_date=None, end_date=None, csvFile='GPS.csv'):
    """
    Read data from a GPS.csv file (in current directory, unless
    otherwise specified) and return as an ndarray.
    """

    # read in GPS file
    data = readCSV(csvFile, formGPS)

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


