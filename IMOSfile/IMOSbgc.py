#! /usr/bin/env python
#
# read data and metadata from an Excel spreadsheet following the IMOS 
# biogeochemical templates

import xlrd
from xlrd.xldate import xldate_as_tuple
from collections import OrderedDict

def openIMOSbgc(filename):
    """
    Open an Excel spreadsheet following the IMOS biogeochemical
    templates, get Sheet 1 and find which rows the metadata and data
    are in. Return the Workbook object and the start/end column
    numbers as a tuple.
    """

    # open file, grab sheet 1 and fist column
    wb = xlrd.open_workbook(filename)
    if wb.nsheets > 1: 
        print "WARNING: file contains more than one worksheet. Only reading sheet 1."
    s = wb.sheets()[0]
    c0 = s.col_values(0)

    # read global attributes into an OrderedDict
    globalStart = c0.index('GLOBAL ATTRIBUTES') + 1
    globalEnd = c0.index('', globalStart)

    # read table column data (variable attributes)
    columnsStart = c0.index('TABLE COLUMNS', globalEnd) + 1
    columnsEnd = c0.index('', columnsStart)

    # read data 
    dataHeader = c0.index('DATA', columnsEnd) + 1
    dataStart = dataHeader + 1
    dataEnd = s.nrows

    return (wb, globalStart, globalEnd, columnsStart, columnsEnd, dataStart, dataEnd)


def readIMOSbgc(filename, convertDate=True):
    """
    Read data and metadata from an Excel spreadsheet following the
    IMOS biogeochemical templates. If convertDate is True, convert the
    time column to a date/time tuple.
    """

    (wb, gStart, gEnd, cStart, cEnd, dStart, dEnd) = openIMOSbgc(filename)
    s = wb.sheets()[0]
    data = []
    for r in range(dStart, dEnd):
        row = s.row_values(r)
        row[0] = xldate_as_tuple(row[0], wb.datemode)
        data.append( row )       

    return data
                    


if __name__=='__main__':
    import sys
    if len(sys.argv) < 2: exit()
    data = readIMOSbgc(sys.argv[1])
    for row in data:
        for cell in row:
            if type(cell)==unicode or type(cell)==str: 
                print '"'+cell+'",',
            else: 
                print str(cell)+',',
        print
             
   
