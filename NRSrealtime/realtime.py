#! /usr/bin/env python
#
# Python module to process real-time data from ANMN NRS moorings.
#
# 2011  Marton Hidas 

import numpy as np
import csv


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
    Format should be given as a numpy dtype object, with labels matching
    the column headers in the file.
    """

    # open file
    f = open(filename, 'rb')
    rd = csv.reader(f)

    # read in header & compare to format?
    head = rd.next()   # first line of file

    # convert parsed rows into a list of tuples
    table = []
    for row in rd:
        table.append(tuple(row))
           
    # convert this raw table into a numpy array
    arr = np.array(table, dtype=format)
 
    return arr


### module variables ###################################################

# formWQM = 

