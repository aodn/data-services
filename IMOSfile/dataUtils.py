#! /usr/bin/env python
#
# Basic functions for common file- & data-manipulation tasks


### reading data in csv files

import csv
import numpy as np
from datetime import datetime


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



### converting data values

def timeFromString(timeStr, epoch):
    """
    Convert time from a YYYY-MM-DDThh:mm:ssZ string to two arrays,
    returned as a tuple. The first gives the decimal days from the epoch
    (given as a datetime obect). The second is an array of datetime
    objects.
    """
    dtime = []
    time  = []
    for tstr in timeStr: 
        dt = datetime.strptime(tstr, '%Y-%m-%dT%H:%M:%SZ')
        dtime.append(dt)
        time.append((dt-epoch).total_seconds())

    time = np.array(time) / 3600. / 24.
    dtime = np.array(dtime)

    return (time, dtime)


