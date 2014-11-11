#! /usr/bin/env python
#
# Basic functions for common file- & data-manipulation tasks


### reading data in csv files

import csv
import numpy as np
from datetime import datetime, timedelta
from netCDF4 import Dataset

# use Agg backend for so code can run in background
import matplotlib
if matplotlib.get_backend() <> 'Agg':
    matplotlib.use('Agg')
from matplotlib.pyplot import figure
from matplotlib.ticker import ScalarFormatter


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

def timeFromString(timeStr, epoch, format='%Y-%m-%dT%H:%M:%SZ'):
    """
    Convert time from a string to two arrays, returned as a tuple. The
    first gives the decimal days from the epoch (given as a datetime
    obect). The second is an array of datetime objects. 
    The default input format (as defined for datetime.strptime) is
    '%Y-%m-%dT%H:%M:%SZ'.
    """
    dtime = []
    time  = []
    for tstr in timeStr: 
        dt = datetime.strptime(tstr, format)
        dtime.append(dt)
        time.append((dt-epoch).total_seconds())

    time = np.array(time) / 3600. / 24.
    dtime = np.array(dtime)

    return (time, dtime)



### sorting & subsetting data

def timeSort(time, dtime, data):
    """
    Given a data set and corresponding time arrays (outputs of
    readCSV() followed by timeFromString()), sort the data in
    chronological order. Return all three arrays.
    """

    # sort in chronological order
    ii = np.argsort(time, kind='quicksort')
    data = data[ii]
    time = time[ii]
    dtime = dtime[ii]

    return time, dtime, data


def timeSubset(time, dtime, data, start_date=None, end_date=None):
    """
    Given a data set and corresponding time arrays (outputs of
    readCSV() followed by timeFromString()), select a subset based on
    the given start and end dates (datetime objects). Return all three
    arrays.

    Assumes data are in chronological order! Results will be
    unpredictable if they are not.
    """

    # select time range
    i = 0
    j = len(time)
    if start_date:
        while i < j and dtime[i] < start_date:
            i += 1
    if end_date:
        while i < j and dtime[j-1] > end_date: 
            j -= 1
    if i == j: 
        print 'No data in selected date range!'
        exit()
    data = data[i:j]
    time = time[i:j]
    dtime = dtime[i:j]

    return time, dtime, data


def timeSortAndSubset(time, dtime, data, start_date=None, end_date=None):
    """
    Given a data set and corresponding time arrays (outputs of
    readCSV() followed by timeFromString()), sort the data in
    chronological order and select a subset based on the given start
    and end dates (datetime objects). Return all three arrays.
    """

    # sort in chronological order
    time, dtime, data = timeSort(time, dtime, data)

    # select time range
    return timeSubset(time, dtime, data, start_date, end_date)

    

### looking at netCDF files

def ncListVar(ncFile, attList=['standard_name','long_name','units']):
    """
    Print attributes and statistics for each variable in a netCDF
    file. The required attributes are specified in attList.

    ncFile can be a filename or OPeNDAP URL, or an open
    netCDF4.Dataset object.
    """

    # open file
    if type(ncFile) == str: 
        F = Dataset(ncFile)
    else: 
        F = ncFile

    print 'variable_name,type,dimensions,'+','.join(attList)

    # for each variable...
    for vname, v in F.variables.items():
        row = [vname, v.dtype.name]
        row.append('"' + ','.join(v.dimensions) + '"')

        # read each attribute
        for att in attList:
            try:
                value = v.getncattr(att)
            except AttributeError:
                row.append('')
                continue
            if type(value) == str: 
                row.append('"'+value+'"')
            else: 
                row.append(str(value))

        print ','.join(row)



### plotting

def plotRecent(dtime, variable, filename='plot.png', plot_days=7, xlabel='Time', ylabel='', title=''):
    """
    Quick plot of the recent values of a variable.
    Returns the number of data points plotted.
    """ 

    # select time range to plot
    now = datetime.utcnow()
    start = now - timedelta(plot_days)
    ii = np.where(dtime > start)[0]
    if len(ii) == 0: return 0

    # create plot
    fig = figure()
    ax = fig.add_subplot(111)
    ax.yaxis.set_major_formatter( ScalarFormatter(useOffset=False) )
    ax.plot(dtime[ii], variable[ii])
    ax.axis(xmin=start, xmax=now)

    if xlabel: ax.set_xlabel(xlabel)
    if ylabel: ax.set_ylabel(ylabel)
    if title: ax.set_title(title)

    fig.savefig(filename)

    return len(ii)
