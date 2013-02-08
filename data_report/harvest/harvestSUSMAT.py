#! /usr/bin/env python
#
# Read data from an NRS Suspended Matter data file (Excel) and store
# store it in the report database.

import numpy as np
from psycopg2 import connect
import argparse
from getpass import getpass
from IMOSfile.IMOSbgc import readIMOSbgc

# list of database columns to write to
colName = ['sample_time',
          'site_code',
          'sample_lat',
          'sample_lon',
          'sample_depth',
          'sample_qc',
          'sample_comment',
          'sample_number',
          'tss',
          'inorganic_fraction',
          'organic_fraction',
          'secchi_depth',
          'secchi_comment']
fStr = "'%s'"
fFloat = '%f'
fInt = '%d'
colForm = ['%s',
           fStr,
           fFloat,
           fFloat,
           fFloat,
           fInt,
           fStr,
           fInt,
           fFloat,
           fFloat,
           fFloat,
           fFloat,
           fStr]     
nCol = len(colName)
assert len(colForm) == nCol, 'colForm and colName are not the same length!'
timeCol = colName.index('sample_time')
depthCol = colName.index('sample_depth')

# numeric code to represent depth of 'WC'
depthWCcode = -111

# get filename from command line
parser = argparse.ArgumentParser() 
parser.add_argument('file', help='IMOS SUSMAT.xls file')
args = parser.parse_args()

# read data from file
data = readIMOSbgc(args.file)

# connect to database
host = 'dbdev.emii.org.au'
db = 'report_db'
user = 'report'
table = 'anmn.nrs_susmat'
password = getpass()
conn = connect(host=host, user=user, password=password, database=db)
if not conn:
    print 'Failed to connect to database!'
    exit()
print 'Connected to %s database on %s' % (db, host)
curs = conn.cursor()

# insert new data
selectSQL = """
SELECT pkid                                                      
FROM %s
WHERE sample_time=%s AND site_code='%s';
""" 
insertCols = colName + ['first_indexed', 'last_indexed']
insertSQL = ('INSERT INTO ' + table + 
             '(' +  ', '.join(insertCols) + ') VALUES (%s);')
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

    # add update timestamps
    row += ['CURRENT_TIMESTAMP', 'CURRENT_TIMESTAMP']

    # insert row
    rowSQL = insertSQL % ', '.join(row) 
    print rowSQL
    curs.execute(rowSQL)
    print curs.statusmessage
    print


# commit changes & close db connection
conn.commit()
conn.close()

print '\nDone!'
