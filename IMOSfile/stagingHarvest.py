#! /usr/bin/env python
#
# Read a listing of filenames on staging, parse their details and enter them into a database.


from IMOSfile.IMOSfilename import parseFilename
import re
from sqlite3 import connect
from datetime import datetime
import os
from netCDF4 import Dataset
import argparse


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

parser = argparse.ArgumentParser()
parser.add_argument('baseDir', help='base of directory tree to harvest')
parser.add_argument('-n', dest='readNcAttributes', action="store_false", default=True,
                    help="don't open netCDF files to read attributes")
args = parser.parse_args()
baseDir = args.baseDir

if baseDir.find('staging')>=0:
    dbTable = 'staging'
elif baseDir.find('opendap')>=0:
    dbTable = 'opendap'
else:
    dbTable = raw_input('db table to harvest into:')

if connect.__module__ == 'psycopg2':
    timeFormat = ",timestamptz '%s UTC'"
elif connect.__module__ == '_sqlite3':
    timeFormat = ",'%s'"

# connect to database
db = 'harvest.db'
conn = connect(db)
if not conn:
    print 'Failed to connect to database!'
    exit()
print 'Connected to %s' % db
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

        # if it's a netCDF file, check toolbox_version
        if args.readNcAttributes:
            if info['extension'] == 'nc':
                D = Dataset(os.path.join(curDir, fileName))
                if 'toolbox_version' not in D.ncattrs():
                    err.append('No toolbox_version attribute')
                elif D.toolbox_version != '2.2':
                    err.append('toolbox_version is ' + D.toolbox_version)

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
                sql += timeFormat % info[col].isoformat(' ')
            else:
                sql += ",NULL"

        sql += ");"

        curs.execute(sql)
        nFiles += 1


conn.commit()
conn.close()

print nFiles, 'files entered'
print 'done'

    
    
    
    
    
