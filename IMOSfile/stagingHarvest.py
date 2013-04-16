#! /usr/bin/env python
#
# Read a listing of filenames on staging, parse their details and enter them into a database.


from IMOSfile.IMOSfilename import parseFilename
import sys
import re
from psycopg2 import connect



def dataCategory(dataCode):
    "Return the appropriate data category for a file with the given data codes."
    code = set(dataCode)

    if code.issubset('TP'): return 'Temperature'
    code -= set('TP')

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
    path = join(basePath, info['facility'], info['sub_facility'], info['site_code'], info['data_category'])
    if info['file_version'] == 'FV00':
        path = join(path, 'non-QC')

    return path


### MAIN ###

if len(sys.argv) < 2:
    exit()

inFile = sys.argv[1]
listFile = open(inFile)


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


dbColumns = ['facility', 'sub_facility', 'data_code', 'data_category', 'site_code', 'platform_code', 'file_version', 'product_code', 'deployment_code', 'instrument', 'instrument_depth', 'start_time', 'end_time', 'creation_time']
dateCol = len(dbColumns) - 3
sql0 = 'INSERT INTO %s(source_path,filename,dest_path,%s) ' % (dbTable, ','.join(dbColumns))

print 'harvesting...'
curDir = '??'
nFiles = 0
for line in listFile:

    line = line.rstrip()
    if line == '': continue

    # is line a directory heading?
    m = re.findall('^(/.*):', line)
    if m:
        curDir = m[0]
        continue

    # if not, try to parse it as a filename
    info, err = parseFilename(line, minFields=8)
    if err: continue

    # remove E and R from data code, work out category and destination path
    info['data_code'] = info['data_code'].translate(None, 'ER')
    info['data_category'] = dataCategory(info['data_code'])

    sql = sql0 + "VALUES('%s'" % curDir  # source_path
    sql += ",'%s'" % line  # filename 
    sql += ",'%s'" % destPath(info)  
    
    for col in dbColumns[:dateCol]:
        sql += ",'%s'" % info[col]
        
    for col in dbColumns[dateCol:]:
        sql += ",timestamptz '%s UTC'" % info[col].isoformat(' ')
        
    sql += ");"

    curs.execute(sql)
    nFiles += 1

conn.commit()
conn.close()

print nFiles, 'files entered'
print 'done'

    
    
    
    
    
