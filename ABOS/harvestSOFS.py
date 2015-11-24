#! /usr/bin/env python
#
# sort SOFS files into the appropriate directories on opendap.


from IMOSfilename import parseFilename
import re
from sqlite3 import connect
from datetime import datetime
import os
import argparse


def dataCategory(info):
    """
    Return the appropriate data category for a file with the given
    attributes (info as returned by parseFilename()).
    """

    if info['data_code'] == 'CMST':
        return 'Surface_properties'

    if info['data_code'] == 'FMT':
        return 'Surface_fluxes'

    if info['data_code'] == 'W':
        return 'Surface_waves'

    if info['data_code'] == 'V':
        return 'Sub-surface_currents'

    if info['data_code'] in ['PT', 'CPT']:
        return 'Sub-surface_temperature_pressure_conductivity'

    return '???'
    

def destPath(info, basePath='/mnt/imos-t3/IMOS/opendap'):
    """
    Return the pubplic directory path for a file with the given info
    (as returned by parseFilename()).
    """
    from os.path import join

    if not info.has_key('data_category'):
        info['data_category'] = dataCategory(info)

    if info['data_category'] == '???':
        return ''

    path = join(basePath, 'ABOS', 'ASFS', 'SOFS', info['data_category'])
    
    if type(info['end_time']) is datetime:
        # whole-deployment delayed-mode file, no further sub-directories
        return path

    if info['product_code'] != '1-min-avg':
        # i.e. not a daily delayed-mode product
        path = join(path, 'Real-time')

    path = join(path, info['start_time'].strftime('%Y') + '_daily' )

    return path


### MAIN ###

parser = argparse.ArgumentParser()
parser.add_argument('baseDir', help='base of directory tree to harvest')
args = parser.parse_args()
baseDir = args.baseDir

if baseDir.find('opendap')>=0:
    dbTable = 'opendap'
else:
    dbTable = 'staging'


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


dbColumns = ['dest_path', 'extension', 'facility', 'sub_facility', 'data_code', 'data_category', 'site_code', 'platform_code', 'file_version', 'product_code', 'deployment_code', 'instrument', 'instrument_depth', 'filename_errors', 'start_time', 'end_time', 'creation_time']
dateCol = len(dbColumns) - 3
sql0 = 'INSERT INTO %s(source_path,filename,%s) ' % (dbTable, ','.join(dbColumns))

print 'harvesting...'
nFiles = 0
for curDir, dirs, files in os.walk(baseDir):
    print curDir

    for fileName in files:

        # try to parse filename
        info, err = parseFilename(fileName, minFields=6)

        # if not netcdf file, skip with warning
        if info['extension'] != 'nc':
            print 'WARNING! Non-netCDF file:', info['filename']
            continue

        # work out category and destination path
        info['data_category'] = dataCategory(info)
        info['filename_errors'] = ';  '.join(err).replace("'", "''")
        info['dest_path'] = destPath(info)

        sql = sql0 + "VALUES('%s'" % curDir  # source_path
        sql += ",'%s'" % fileName

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
