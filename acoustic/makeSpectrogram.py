#! /usr/bin/env python
#
# Read in a Matlab file containing a spectrogram and convert it to a
# series of .png bitmaps of a given size

import sys, os
import numpy as np
from scipy.io import loadmat
from matplotlib.pyplot import imsave
from datetime import datetime, timedelta

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


move_cmd = '/bin/mv -nv '

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
nRec = 100
while iStart < nRec:

    # find end of chunk
    iDate = time[iStart].date()
    iEnd = iStart + 1
    while iEnd < nRec and time[iEnd].date() == iDate:
        iEnd += 1

    # create date directory and save the image
    iDateStr = iDate.strftime('%Y%m%d')
    if not os.path.exists(iDateStr): os.mkdir(iDateStr)
    chunkName = curtinID + '_%sSP.png' % iDateStr
    imsave(iDateStr+'/'+chunkName, spectrum[:,iStart:iEnd], origin='lower', vmin=smin, vmax=smax)

    # print some info for db - spectrograms table ...
    tStart = time[iStart]
    print >>specInfo, "  ('%s', '%s', '%s', %d, timestamptz '%s UTC')," % (curtinID, iDateStr, chunkName, iEnd-iStart, tStart.isoformat(' '))

    # ... and recordings table
    for i in range(iStart, iEnd):
        print >>recInfo, "  ('%s', %3d, %s, timestamptz '%s UTC')," % (recName[i], i-iStart, iDateStr, time[i].isoformat(' '))

    # if given, move preview images here
    if previewDir:
        dateSpecDir = os.path.join(iDateStr, 'recording_spec')
        dateWaveDir = os.path.join(iDateStr, 'recording_wave')
        if not os.path.exists(dateSpecDir): os.mkdir(dateSpecDir)
        if not os.path.exists(dateWaveDir): os.mkdir(dateWaveDir)
        for i in range(iStart, iEnd):
            cmd = move_cmd + os.path.join(previewDir, recName[i]+'SP.png') + ' ' + dateSpecDir
            os.system(cmd)
            cmd = move_cmd + os.path.join(previewDir, recName[i]+'WF.png') + ' ' + dateWaveDir
            os.system(cmd)

    if rawDir:
        dateRawDir = os.path.join(iDateStr, 'raw')
        if not os.path.exists(dateRawDir): os.mkdir(dateRawDir)
        for i in range(iStart, iEnd):
            fileName = recName[i]+'.DAT'
            os.rename(os.path.join(rawDir, fileName), os.path.join(dateRawDir, fileName))


    # start next chunk
    iStart = iEnd
    day += 1


# close output files
specInfo.write('\nCOMMIT;\n')
specInfo.close()
recInfo.write('\nCOMMIT;\n')
recInfo.close()
