#! /usr/bin/env python
#
# read data and metadata from an Excel spreadsheet following the IMOS 
# biogeochemical templates

import xlrd
from xlrd.xldate import xldate_as_tuple
from collections import OrderedDict
import numpy as np


### reading Excel files #################################

def openBGC(filename):
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


def readBGC(filename, convertDate=True):
    """
    Read data and metadata from an Excel spreadsheet following the
    IMOS biogeochemical templates. If convertDate is True, convert the
    time column to a date/time tuple.
    """

    (wb, gStart, gEnd, cStart, cEnd, dStart, dEnd) = openBGC(filename)
    s = wb.sheets()[0]
    data = []
    for r in range(dStart, dEnd):
        row = s.row_values(r)
        row[0] = xldate_as_tuple(row[0], wb.datemode)
        data.append( row )       

    return data



### harvesting to database #################################

## constants

# numeric code to represent depth of 'WC'
depthWCcode = -111

# format strings
fStr = "'%s'"
fFloat = '%f'
fInt = '%d'


def harvestBGC(fileName, columns, dbConnection, table):
    """
    Harvest data from an IMOS biogeochemical Excel file into a
    database.

    fileName: The Excel file to harvest.

    columns: A list of lists specifying the column mapping from Excel
             to db. The outer list has an entry for each column to be
             harvested. Each entry is a list of three strings: 1) the
             column heading in Excel 2) the name of the corresponding
             column in the db table 3) a printf-style format to add
             values in the column to an SQL INSERT/UPDATE statement.

             The columns sample_time, sample_depth, site_code and
             sample_number must be included.

    dbConnection: An open database connection to write to.

    table: The database table to update.

    Returns as a tuple the numbers of rows inserted and updated.
    """

    # read data from file
    data = readBGC(fileName)

    # break down columns into lists and numbers as needed
    nCol = len(columns)
    columns = np.array(columns)
    colNameExcel = list(columns[:,0])
    colName = list(columns[:,1])
    colForm = list(columns[:,2])
    timeCol = colName.index('sample_time')
    depthCol = colName.index('sample_depth')
    siteCol = colName.index('site_code')
    sampleCol = colName.index('sample_number')

    # set up SQL command templates
    selectSQL = ("SELECT pkid  " + 
                 "FROM %s   " +
                 "WHERE sample_time=%s AND site_code=%s AND sample_depth=%s AND sample_number=%s;")
    insertCols = colName + ['first_indexed', 'last_indexed']
    insertSQL = ('INSERT INTO ' + table + 
                 '(' +  ', '.join(insertCols) + ') VALUES (%s);')
    updateCols = colName + ['last_indexed']
    updateSQL = ('UPDATE ' + table +
                 '\nSET (' + ', '.join(updateCols) + ') = \n(%s)' +
                 '\nWHERE pkid=%d;')

    # get database cursor
    dbConnection.autocommit = True  # commit all transactions when executed
    curs = dbConnection.cursor()

    # open log file
    LOG = open('harvest.log', 'a')
    print >>LOG, '\n', 77*'-'
    print >>LOG, 'Harvesting %s\n' % fileName

    # loop through data
    nInsert = nUpdate = 0
    for row in data:
        # convert time from tuple to timestamptz string
        row[timeCol] = "timestamptz '%4d-%02d-%02d %02d:%02d:%02d UTC'" % row[timeCol]
        # convert 'WC' depth to numeric value
        if row[depthCol] == 'WC':
            row[depthCol] = depthWCcode
        # format each value, replacing any empty values with NULL
        for c in range(nCol):
            if row[c] == '':
                row[c] = 'NULL'
            else:
                row[c] = colForm[c] % row[c]

        # find out if this row is already in the db
        query = selectSQL % (table, row[timeCol], row[siteCol], row[depthCol], row[sampleCol])
        print >>LOG, query
        curs.execute(query)
    
        if curs.rowcount == 0:  # not yet in db
            # add update timestamps
            row += ['CURRENT_TIMESTAMP', 'CURRENT_TIMESTAMP']
            # insert new row
            rowSQL = insertSQL % ', '.join(row) 
            print >>LOG, rowSQL
            curs.execute(rowSQL)
            if curs.statusmessage=='INSERT 0 1':
                nInsert += 1
            print >>LOG, curs.statusmessage, '\n'

        elif curs.rowcount == 1:  # already in db, update
            pkid = curs.fetchall()[0][0]
            print >>LOG, 'Matching row found. pkid=', pkid
            # add update timestamps
            row += ['CURRENT_TIMESTAMP']
            rowSQL = updateSQL % (', '.join(row), pkid)
            print >>LOG, rowSQL
            curs.execute(rowSQL)
            if curs.statusmessage=='UPDATE 1':
                nUpdate += 1
            print >>LOG, curs.statusmessage, '\n'

        else:   # more than one matching row found - this should not happen!
            res = curs.fetchall()
            print 'WARNING: Multiple matching rows! pkid=', res
            continue

    print '\nInserted %d rows.' % nInsert
    print 'Updated %d rows.' % nUpdate
    print '\nDone!'

    return nInsert, nUpdate

                    


if __name__=='__main__':
    import sys
    if len(sys.argv) < 2: exit()
    data = readBGC(sys.argv[1])
    for row in data:
        for cell in row:
            if type(cell)==unicode or type(cell)==str: 
                print '"'+cell+'",',
            else: 
                print str(cell)+',',
        print
             
   
