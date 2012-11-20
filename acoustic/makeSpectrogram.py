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
            cmd = moveCmd + ' ' + os.path.join(fromDir, fn) + ' ' + os.path.join(toDir, fn)
            if os.system(cmd) <> 0:
                print 'F! ', cmd
                continue

        ok.append(i)

    return ok


# get file from command line
if len(sys.argv) < 2:
    print 'usage:\n  '+sys.argv[0]+' <site_code>-<curtin_id>.mat [preview_dir  [raw_dir]]'
    exit()
infile = sys.argv[1]
siteDep = infile.split('.')[0]
siteCode, curtinID = siteDep.split('-')
previewDir = rawDir = ''
if len(sys.argv) > 2:
    previewDir = sys.argv[2]
if len(sys.argv) > 3:
    rawDir = sys.argv[3]


# load file and extract variables
data = loadmat(infile)
print data['__header__']
spectrum = data['Spectrum']
nFreq, nRec = spectrum.shape
print nFreq, nRec
recName = data['File_name']

# determine range of spectrum values
sp = spectrum[np.where(spectrum > 0)]
smin, smax = np.percentile(sp, (0.1, 99.9))

# convert time from datestr(0) in Matlab to datetime
tt = data['Start_time_day'][0,:] - 367  # convert to offset from 0001-01-01
time = []
for t in tt:
    time.append( datetime(1,1,1) + timedelta(t) )


# connect to db
host = 'dbdev.emii.org.au'
db = 'maplayers'
conn = connect(host=host, user='anmn', password='anmn', database=db)
curs = conn.cursor()
print 'Connected to %s database on %s' % (db, host)
# get metadata for the deployment
query = 'SELECT pkid,site_code,deployment_name FROM acoustic_deployments WHERE curtin_id = %s' % curtinID
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


# open files for sql output and write headers
specInfo = open('spec_fill.sql', 'w')
specInfo.write('BEGIN;\n\n')
specInfo.write('INSERT INTO acoustic_spectrograms(acoustic_deploy_fk, subdirectory, filename, width, time_start)  VALUES\n')
recInfo = open('rec_fill.sql', 'w')
recInfo.write('BEGIN;\n\n')
recInfo.write('INSERT INTO acoustic_recordings(filename, x_coord, acoustic_spec_fk, time_recording_start) VALUES\n')

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

    # create date directory and save the image
    iDateStr = iDate.strftime('%Y%m%d')
    if not os.path.isdir(iDateStr): os.mkdir(iDateStr)

    # if location given, move raw data here
    iOK = range(iStart, iEnd)
    if rawDir:
        dateRawDir = os.path.join(iDateStr, 'raw')
        iOK = moveFiles(rawDir, dateRawDir, recName[iStart:iEnd], '.DAT')
        iOK = np.array(iOK) + iStart

    # if location given, move preview images here (only those for which we have raw data)
    if previewDir and len(iOK)>0:
        dateSpecDir = os.path.join(iDateStr, 'recording_spec')
        dateWaveDir = os.path.join(iDateStr, 'recording_wave')
        moveFiles(previewDir, dateSpecDir, recName[iOK], 'SP.png')
        moveFiles(previewDir, dateWaveDir, recName[iOK], 'WF.png')

    # if raw files missing, blank out corresponding columns in spectrogram
    if len(iOK) < (iEnd - iStart):
        iALL = range(iStart, iEnd)
        iBAD = list( set(iALL) - set(iOK) )
        spectrum[:,iBAD] = 0

    # save spectrogram chunk
    chunkName = curtinID + '_%sSP.png' % iDateStr
    chunkPath = os.path.join(iDateStr, chunkName)
    imsave(chunkPath, spectrum[:,iStart:iEnd], origin='lower', vmin=smin, vmax=smax)

    # print some info for db - spectrograms table ...
    tStart = time[iStart]
    print >>specInfo, "  ('%s', '%s', '%s', %d, timestamptz '%s UTC')," % (db_dep_pkid, iDateStr, chunkName, iEnd-iStart, tStart.isoformat(' '))

    # ... and recordings table
    for i in iOK:
        print >>recInfo, "  ('%s', %3d, %s, timestamptz '%s UTC')," % (recName[i], i-iStart, iDateStr, time[i].isoformat(' '))

    # start next chunk
    iStart = iEnd
    day += 1


# close output files
specInfo.write('\nCOMMIT;\n')
specInfo.close()
recInfo.write('\nCOMMIT;\n')
recInfo.close()
