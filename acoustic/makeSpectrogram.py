#! /usr/bin/env python
#
# Read in a Matlab file containing a spectrogram and convert it to a
# series of .png bitmaps of a given size

import sys, os
import numpy as np
from scipy.io import loadmat
from matplotlib.pyplot import imsave
from datetime import datetime, timedelta
from psycopg2 import connect
import argparse


def moveFiles(fromDir, toDir, fileNames, nameEnd='', moveCmd='mv -nv'):
    """
    Move files from fromDir to toDir. nameEnd is appended to each
    filename in the list fileNames and the system command moveCmd is
    used to move one file at a time. If the file already exists in
    toDir, it is skipped.  If toDir does not exist, it is created.
    Log errors.
    Return the indices of fileNames that were successfully moved or already
    existed at the destination.
    """

    ok = []
    if not os.path.isdir(toDir): os.mkdir(toDir)

    for i in range(len(fileNames)):
        fn = fileNames[i] + nameEnd

        if not os.path.isfile(os.path.join(toDir, fn)): 
            cmd = moveCmd + ' ' + os.path.join(fromDir, fn) + ' ' + os.path.join(toDir, fn) + ' 2>>' + moveErr
            if os.system(cmd) <> 0: continue

        ok.append(i)

    return ok


# parse command line
parser = argparse.ArgumentParser() #usage="%prog [options] <site_code>-<curtin_id>.mat")
parser.add_argument('matfile', help='spectrogram file, named <site_code>-<curtin_id>.mat')
parser.add_argument('-u', "--updateDB", action="store_true", default=False,
                  help="update database tables")
parser.add_argument("-p", dest="previewDir", help="directory containing preview images", metavar="DIR")
parser.add_argument("-r", dest="rawDir", help="directory containing raw data", metavar="DIR")
args = parser.parse_args()

siteDep = args.matfile.split('.')[0]
try:
    siteCode, curtinID = siteDep.split('-')
except:
    parser.error()

# file to log move errors
moveErr = 'move.err'
if os.path.isfile(moveErr): os.remove(moveErr)

# load file and extract variables
data = loadmat(args.matfile)
spectrum = data['Spectrum']
nFreq, nRec = spectrum.shape
recName = data['File_name']

# determine range of spectrum values
sp = spectrum[np.where(spectrum > 0)]
smin, smax = np.percentile(sp, (0.1, 99.9))

# convert time from datestr(0) in Matlab to datetime
tt = data['Start_time_day'][0,:] - 367  # convert to offset from 0001-01-01
time = []
for t in tt:
    time.append( datetime(1,1,1) + timedelta(t) )

# open files to log details, and lists to store them for later write to db
specLog = open('spec.log', 'w')
recLog = open('rec.log', 'w')
specInfo = []
recInfo = {}

# save chunks of spectrum in images
print 'Creating daily chunks' 
iStart = 0
day = 0
while iStart < nRec:

    # find end of chunk
    iDate = time[iStart].date()
    iEnd = iStart + 1
    while iEnd < nRec and time[iEnd].date() == iDate:
        iEnd += 1
    iLen = iEnd - iStart

    # create date directory and save the image
    iDateStr = iDate.strftime('%Y%m%d')
    if not os.path.isdir(iDateStr): os.mkdir(iDateStr)
    print iDateStr

    # if location given, move raw data here
    iOK = range(iStart, iEnd)
    if args.rawDir:
        dateRawDir = os.path.join(iDateStr, 'raw')
        iOK = moveFiles(args.rawDir, dateRawDir, recName[iStart:iEnd], '.DAT')
        iOK = np.array(iOK) + iStart

    # if location given, move preview images here (only those for which we have raw data)
    if args.previewDir and len(iOK)>0:
        dateSpecDir = os.path.join(iDateStr, 'recording_spec')
        dateWaveDir = os.path.join(iDateStr, 'recording_wave')
        moveFiles(args.previewDir, dateSpecDir, recName[iOK], 'SP.png')
        moveFiles(args.previewDir, dateWaveDir, recName[iOK], 'WF.png')

    # if raw files missing, blank out corresponding columns in spectrogram
    if len(iOK) < iLen:
        iALL = range(iStart, iEnd)
        iBAD = list( set(iALL) - set(iOK) )
        spectrum[:,iBAD] = 0

    # save spectrogram chunk
    chunkName = curtinID + '_%sSP.png' % iDateStr
    chunkPath = os.path.join(iDateStr, chunkName)
    imsave(chunkPath, spectrum[:,iStart:iEnd], origin='lower', vmin=smin, vmax=smax)

    # save info for db
    tStart = time[iStart]
    specInfo.append( (iDateStr, chunkName, iLen, tStart.isoformat(' ')) )
    print >>specLog, "  ('%s', '%s', '%s', %d, timestamptz '%s UTC')," % (curtinID, iDateStr, chunkName, iLen, tStart.isoformat(' '))

    # ... and recordings table
    recInfo[iDateStr] = []
    for i in iOK:
        recInfo[iDateStr].append( (recName[i], i-iStart, time[i].isoformat(' ')) )
        print >>recLog, "  ('%s', %3d, %s, timestamptz '%s UTC')," % (recName[i], i-iStart, iDateStr, time[i].isoformat(' '))

    # start next chunk
    iStart = iEnd
    day += 1


# close output files
specLog.close()
recLog.close()


# update database?
if not args.updateDB: 
    ans = raw_input('\nUpdate database tables? [y/N]: ')
    if not ans  or  not ans[0] in 'yY': exit()

# connect to db
host = 'dbdev.emii.org.au'
db = 'maplayers'
conn = connect(host=host, user='anmn', password='anmn', database=db)
curs = conn.cursor()
print 'Connected to %s database on %s' % (db, host)

# get metadata for the deployment
query = 'SELECT pkid,site_code,deployment_name FROM acoustic_deployments WHERE curtin_id = %s;' % curtinID
curs.execute(query)
res = curs.fetchall()
if len(res) <> 1:
    print "CurtinID %s not in database!" % curtinID
    exit()
(db_dep_pkid, db_siteCode, db_depName) = res[0]
if siteCode <> db_siteCode:
    print "Site codes don't match! (command line: '%s', db: '%s')" % (siteCode, db_siteCode)
    exit()
print "Deployment name: ", db_depName

# delete any previous entries for this deployment
curs.execute('DELETE FROM acoustic_spectrograms WHERE acoustic_deploy_fk = %d;' % db_dep_pkid)
conn.commit()

# update spectrograms table
print 'Updating spectrograms table...'
specInsert = 'INSERT INTO acoustic_spectrograms(acoustic_deploy_fk, subdirectory, filename, width, time_start)  VALUES (%d, ' % db_dep_pkid
for (iDateStr, chunkName, iLen, tStart) in specInfo:    
    sql = specInsert + "'%s', '%s', %d, timestamptz '%s UTC');" % (iDateStr, chunkName, iLen, tStart)
    curs.execute(sql)
conn.commit()

# ... and recordings table
print 'Updating recordings table...'
for iDateStr in sorted(recInfo.keys()):

    # find out the pkid of the corresponding entry in the spectrograms table
    sql = "SELECT pkid FROM acoustic_spectrograms WHERE acoustic_deploy_fk = %d AND subdirectory = '%s';" % (db_dep_pkid, iDateStr)
    curs.execute(sql)
    res = curs.fetchall()
    if len(res) <> 1:
        print "Query:\n  ", sql
        print "Expected 1 results, got ", len(res)
        exit()
    recInsert = 'INSERT INTO acoustic_recordings(acoustic_spec_fk, filename, x_coord, time_recording_start)  VALUES (%d, ' % res[0][0]
    
    # add entries
    for (recName, x, time) in recInfo[iDateStr]:
        sql = recInsert + "'%s', %d, timestamptz '%s UTC');" % (recName, x, time)
        curs.execute(sql)

    conn.commit()

conn.close()

# and we're done!
