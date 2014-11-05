#! /usr/bin/env python
#
# Use info in the sqlite3 database set up by stagingHarvest.py to
# generate a script that will move the files to the correct public
# directories, archiving any previous versions present.

import sys, time
from sqlite3 import connect
from os.path import join
import argparse
import os

# parse arguments
parser = argparse.ArgumentParser()
parser.add_argument('-c', '--constraint', metavar='SQL',
                    help="additional SQL constraint on what files to move")
parser.add_argument('-d', '--database', metavar='FILE', default='harvest.db',
                    help="database file from stagingHarvest.py")
parser.add_argument('-l', '--log', metavar='FILE',
                    help="log activity to this file")
args = parser.parse_args()

# main storage areas
opendap = os.environ['OPENDAP_DIR'] + '/1/IMOS/opendap'
archive = os.environ['ARCHIVE_DIR']

# connect to database
dbFile = args.database
conn = connect(dbFile)
curs = conn.cursor()

# From move_view, select files which either don't have a version
# already in public or where the version in public is an older version
condition = "old_file IS NULL OR creation_time > old_creation_time"
if args.constraint:
    print '# adding constraint:', args.constraint
    condition = "(%s) AND (%s)" % (condition, args.constraint)
sql = """
SELECT source_path, filename, dest_path, old_file, old_path FROM move_view 
WHERE %s
ORDER BY dest_path;
"""  % condition
curs.execute(sql)

# commands & bits to use in script
MV='rsync -ai --remove-source-files '
MKDIR='mkdir -pv '
dateDir = 'old_' + time.strftime('%Y%m%d')

# open log file and log setup
if args.log:
    LOG = open(args.log, 'w')
    print >>LOG, 'writeMoveScript log\n'
    print >>LOG, 'opendap = %s\narchive = %s\n' % (opendap, archive)
    print >>LOG, 'database = ', args.database
    print >>LOG, 'sql: \n', sql


# keep track of directories made, so we don't try to make them over
# and over again
archiveDirs = set()
publicDirs = set()
prevDir = ''

# for each file...
for source_path, filename, dest_path, old_file, old_path in curs.fetchall():

    if dest_path <> prevDir: 
        print
        print 'echo ........................................................'
        if args.log: print >>LOG, '\n\ndest:', dest_path
 
    if args.log: 
        print >>LOG, 'src:%s\nnew:%s\nold:%s\n' % (source_path, filename, old_file)
 
    # if an older version of the file exists, move it to archive
    if old_file:
        archive_path = join(dest_path.replace(opendap,archive), dateDir)
        if archive_path not in archiveDirs:
            print '\n', MKDIR, archive_path
            archiveDirs.add(archive_path)
        print MV, join(old_path, old_file), '  ', archive_path

    # move new file to public
    if dest_path not in publicDirs:
        print MKDIR, dest_path
        publicDirs.add(dest_path)
    print MV,  join(source_path, filename),  dest_path

    prevDir = dest_path



# close log file
if args.log:
    LOG.close()
