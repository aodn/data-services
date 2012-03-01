#! /usr/bin/env python
#
# Python module to process real-time Wave data from ANMN NRS moorings.


import numpy as np
import csv
from datetime import datetime
import IMOSfile.IMOSnetCDF as inc


### functions #######################################################

def readCSVheader(filename):
    """
    Read the first line of the given CSV file and return a list of
    column titles.
    """
    r = csv.reader(open(filename, 'rb'))
    return r.next()


def readCSV(filename, format):
    """
    Read in a CSV data file, returning a numpy array.
    Format should be given as a numpy dtype object, with labels
    matching the column headers in the file. If the string field
    values read in cannot be converted to the given format, returns the
    raw data (list of row tuples) instead.
    """

    # open file
    f = open(filename, 'rb')
    rd = csv.reader(f)

    # read in header & compare to format
    head = tuple(rd.next())   # first line of file
    if format.names <> head:
        print "WARNING! Field names in format don't match file header!"
        print "... Carrying on regardless ..."

    # convert parsed rows into a list of tuples
    table = []
    for row in rd:
        table.append(tuple(row))
           
    # convert this raw table into a numpy array
    try:
        arr = np.array(table, dtype=format)
    except: 
        print
        print "Couldn't convert data read from "+filename+" to given format!"
        print "Returning raw table instead."
        return table

    return arr



### module variables ###################################################
i = np.int32
f = np.float64
format =  [('Config ID', i),
           ('Trans ID', i),
           ('Record', i),
           ('Header Index', i),
           ('Time', 'S24'),
#           ('WaveHt', f)]
           ('Sig. Wave Height', f)]
formWave = np.dtype(format)

csvFile = 'Wave.csv'
ncFile = 'Wave.nc'


### processing ##########################################################

# read in Wave file
data = readCSV(csvFile, formWave)

# convert time from string to something more numeric
epoch = datetime(1950,1,1)
dtime = []
time  = []
for tstr in data['Time']: 
    dt = datetime.strptime(tstr, '%Y-%m-%dT%H:%M:%SZ')
    dtime.append(dt)
    time.append((dt-epoch).total_seconds())

time = np.array(time) / 3600. / 24.
dtime = np.array(dtime)
waveh = data['Sig. Wave Height']


# Filter data and time arrays to the time range we want
# ...


# create netCDF file
inc.defaultAttributes = inc.attributesFromFile('/home/marty/work/code/NRSrealtime/attributes.txt')  # load default attributes
file = inc.IMOSnetCDFFile(ncFile)
file.title = 'Real-time data from NRSMAI: significant wave height'

TIME = file.setDimension('TIME', time)

VAVH = file.setVariable('VAVH', waveh, ('TIME',))
VAVH.standard_name = 'sea_surface_wave_significant_height'
VAVH.long_name = 'sea_surface_wave_significant_height'
VAVH.units = 'metres'
VAVH.valid_min = 0
VAVH.valid_max = 900
#VAVH._FillValue = ???


file.close()


# create plots
