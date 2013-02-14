#! /usr/bin/env python
#
# Read data from an NRS Suspended Matter data file (Excel) and store
# store it in the report database.

import numpy as np
from psycopg2 import connect
import argparse
from IMOSfile.IMOSbgc import readIMOSbgc

# List of columns in spreadsheet and how they should be transferred
# into database
fStr = "'%s'"
fFloat = '%f'
fInt = '%d'
#           name in Excel         name in db          format
column = [['Time',               'sample_time',       '%s'  ],
          ['Station Code',       'site_code',         fStr  ],
          ['Latitude',           'sample_lat',        fFloat],
          ['Longitude',          'sample_lon',        fFloat],
          ['Depth',              'sample_depth',      fFloat],
          ['Sample QC Flag',     'sample_qc',         fInt  ],
          ['Sample QC comment',  'sample_comment',    fStr  ],
          ['Repeat no.',         'sample_number',     fInt  ],
          ['TSS',                'tss',               fFloat],
          ['Inorganic Fraction', 'inorganic_fraction',fFloat],
          ['Organic Fraction',   'organic_fraction',  fFloat],
          ['Secchi Depth',       'secchi_depth',      fFloat],
          ['Secchi Comments',    'secchi_comment',    fStr  ]] 
nCol = len(column)

# list of database columns to write to
column = np.array(column)
colNameExcel = list(column[:,0])
colName = list(column[:,1])
colForm = list(column[:,2])
                
timeCol = colName.index('sample_time')
depthCol = colName.index('sample_depth')
siteCol = colName.index('site_code')
sampleCol = colName.index('sample_number')

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
conn = connect(host=host, user=user, database=db)
if not conn:
    print 'Failed to connect to database!'
    exit()
print 'Connected to %s database on %s' % (db, host)
conn.autocommit = True  # commit all transactions when executed
curs = conn.cursor()

# insert new data
selectSQL = """
SELECT pkid
FROM %s
WHERE sample_time=%s AND site_code=%s AND sample_depth=%s AND sample_number=%s;
""" 
insertCols = colName + ['first_indexed', 'last_indexed']
insertSQL = ('INSERT INTO ' + table + 
             '(' +  ', '.join(insertCols) + ') VALUES (%s);')
updateCols = colName + ['last_indexed']
updateSQL = ('UPDATE ' + table +
             '\nSET (' + ', '.join(updateCols) + ') = \n(%s)' +
             '\nWHERE pkid=%d;')
nInsert = 0
nUpdate = 0
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
    print query
    curs.execute(query)
    
    if curs.rowcount == 0:  # not yet in db
        # add update timestamps
        row += ['CURRENT_TIMESTAMP', 'CURRENT_TIMESTAMP']
        # insert new row
        rowSQL = insertSQL % ', '.join(row) 
        print rowSQL
        curs.execute(rowSQL)
        if curs.statusmessage=='INSERT 0 1':
            nInsert += 1
            print curs.statusmessage
            print

    elif curs.rowcount == 1:  # already in db, update
        pkid = curs.fetchall()[0][0]
        print 'Matching row found. pkid=', pkid
        # add update timestamps
        row += ['CURRENT_TIMESTAMP']
        rowSQL = updateSQL % (', '.join(row), pkid)
        print rowSQL
        curs.execute(rowSQL)
        if curs.statusmessage=='UPDATE 1':
            nUpdate += 1
            print 'Updated\n'
        

    else:   # more than one matching row found - this should not happen!
        res = curs.fetchall()
        print 'WARNING: Multiple matching rows! pkid=', res
        continue
        

# close db connection
conn.close()

print '\nInserted %d rows.' % nInsert
print 'Updated %d rows.' % nUpdate
print '\nDone!'
