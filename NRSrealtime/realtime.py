#! /usr/bin/env python
#
# Python module to process real-time data from ANMN NRS moorings.
#
# 2011  Marton Hidas 

import numpy as np
import csv
from datetime import datetime



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
           ('Serial No', i),
           ('Nominal Depth', f),
           ('Time', 'S24'),
           ('Temperature', f),
           ('Pressure', f),
           ('Salinity', f),
           ('Dissolved Oxygen', f),
           ('Chlorophyll', f),
           ('Turbidity', f),
           ('Voltage', f)]

formWQM = np.dtype(format)



### processing ##########################################################

# read in WQM file
data = readCSV('WQM.csv', formWQM)

# convert time from string to something more numeric
epoch = datetime(1970,1,1)
dtime = []
time  = []
for tstr in data['Time']: 
    dt = datetime.strptime(tstr, '%Y-%m-%dT%H:%M:%SZ')
    dtime.append(dt)
    time.append((dt-epoch).total_seconds())

time = np.array(time)
dtime = np.array(dtime)
