#! /usr/bin/env python
#
# Python module to process real-time data from ANMN NRS moorings.
#
# 2011  Marton Hidas 

import numpy as np
import csv


def readCSV(filename, format=None):
    """
    Read in a CSV data file of the given format. If format is None,
    read column names from first row of file.
    Return a dictionary of column arrays.
    """

    # open file
    f = open(filename, 'rb')
    dr = csv.DictReader(f)

    # read in header & compare to format?
    # create blank output dict from format
    table = dr.next()  # first record, just to get headers
    for k, v in table.items():
        table[k] = [v] # convert to a list, so we can append

    # for each row:
    for row in dr:
        # add fields to arrays, converting as necessary
        for k, v in row.items():
            table[k].append(v)
            
    return table

