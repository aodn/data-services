#! /usr/bin/env python
#
# Read a listing of filenames on staging, parse their details and enter them into a database.


from IMOSfile.IMOSfilename import parseFilename
import sys
import re
from psycopg2 import connect
from datetime import datetime
import os


def dataCategory(dataCode):
    "Return the appropriate data category for a file with the given data codes."
    code = set(dataCode)

    if code.issubset('TPZ'): return 'Temperature'
    code -= set('TPZ')

    if code.intersection('CS'):
        if code.intersection('BGKOU'):
            return 'Biogeochem_timeseries'
        else:
            return 'CTD_timeseries'

    if set('VA').issubset(code): return 'Velocity'

    if 'W' in code: return 'Wave'

    if 'M' in code: return 'Meteorology'

    return '???'
    

def destPath(info, basePath='/mnt/imos-t3/IMOS/opendap'):
    """
    Return the pubplic directory path for a file with the given info
    (as returned by parseFilename(), with added data_category).
    """
    from os.path import join

    if not info.has_key('data_category'):
        info['data_category'] = dataCategory(info['data_code'])

    if (info['facility'] == '' or
        info['sub_facility'] == '' or
        info['site_code'] == '' or
        info['data_category'] == '???'):
        return '???'

    path = join(basePath, info['facility'], info['sub_facility'], info['site_code'], info['data_category'])
    if info['file_version'] == 'FV00':
        path = join(path, 'non-QC')

    return path


### MAIN ###

if len(sys.argv) < 2:
    exit()
baseDir = sys.argv[1]


# connect to database
host = 'dbdev.emii.org.au'
db = 'report_db'
user = 'report'
dbTable = 'anmn.staging_files'
conn = connect(host=host, user=user, database=db)
if not conn:
    print 'Failed to connect to database!'
    exit()
print 'Connected to %s database on %s' % (db, host)
curs = conn.cursor()


dbColumns = ['extension', 'facility', 'sub_facility', 'data_code', 'data_category', 'site_code', 'platform_code', 'file_version', 'product_code', 'deployment_code', 'instrument', 'instrument_depth', 'filename_errors', 'start_time', 'end_time', 'creation_time']
dateCol = len(dbColumns) - 3
sql0 = 'INSERT INTO %s(source_path,filename,dest_path,%s) ' % (dbTable, ','.join(dbColumns))

print 'harvesting...'
nFiles = 0
for curDir, dirs, files in os.walk(baseDir):
    print curDir

    for fileName in files:

        # try to parse filename
        info, err = parseFilename(fileName, minFields=8)

        # remove E and R from data code, work out category and destination path
        info['data_code'] = info['data_code'].translate(None, 'ER')
        info['data_category'] = dataCategory(info['data_code'])
        info['filename_errors'] = ';  '.join(err).replace("'", "''")

        sql = sql0 + "VALUES('%s'" % curDir  # source_path
        sql += ",'%s'" % fileName
        sql += ",'%s'" % destPath(info)  

        for col in dbColumns[:dateCol]:
            if info[col]:
                sql += ",'%s'" % info[col]
            else:
                sql += ",NULL"

        for col in dbColumns[dateCol:]:
            if type(info[col]) is datetime:
                sql += ",timestamptz '%s UTC'" % info[col].isoformat(' ')
            else:
                sql += ",NULL"

        sql += ");"

        curs.execute(sql)
        nFiles += 1


conn.commit()
conn.close()

print nFiles, 'files entered'
print 'done'

    
    
    
    
    
