#! /usr/bin/env python
#
# Read in a Matlab file containing a spectrogram and convert it to a
# series of .png bitmaps of a given size

import sys, os
from scipy.io import loadmat
from matplotlib.pyplot import imsave
from datetime import datetime, timedelta

# get file from command line
if len(sys.argv) < 3:
    print 'usage:\n  '+sys.argv[0]+' infile.mat deployment_code'
    exit()
infile = sys.argv[1]
deploymentCode = sys.argv[2]


# load file and extract variables
data = loadmat(infile)
print data['__header__']
spectrum = data['Spectrum']
nFreq, nRec = spectrum.shape
print nFreq, nRec
recName = data['File_name']

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
while iStart < nRec:

    # find end of chunk
    iDate = time[iStart].date()
    iEnd = iStart + 1
    while iEnd < nRec and time[iEnd].date() == iDate:
        iEnd += 1

    # give it a name and save the image
    iDateStr = iDate.strftime('%Y%m%d')
    os.mkdir(iDateStr)
    chunkName = deploymentCode + '_%sSP.png' % iDateStr
    imsave(iDateStr+'/'+chunkName, spectrum[:,iStart:iEnd])

    # print some info for db - spectrograms table ...
    tStart = time[iStart]
    print >>specInfo, "  ('%s', '%s', '%s', %d, timestamptz '%s UTC')," % (deploymentCode, iDateStr, chunkName, iEnd-iStart, tStart.isoformat(' '))

    # ... and recordings table
    for i in range(iStart, iEnd):
        print >>recInfo, "  ('%s', %3d, %s, timestamptz '%s UTC')," % (recName[i], i-iStart, iDateStr, time[i].isoformat(' '))

    # start next chunk
    iStart = iEnd
    day += 1


# close output files
specInfo.write('\nEND;\n')
specInfo.close()
recInfo.write('\nEND;\n')
recInfo.close()
