#! /usr/bin/env python
#
# Read in a Matlab file containing a spectrogram and convert it to a
# series of .png bitmaps of a given size

import sys
from scipy.io import loadmat
from matplotlib.pyplot import imsave
from datetime import datetime, timedelta

# get file from command line
if len(sys.argv) < 2:
    print 'usage:\n  '+sys.argv[0]+' infile.mat [deployment_code]'
    exit()

infile = sys.argv[1]
if len(sys.argv) > 2: deploymentCode = sys.argv[2]
else: deploymentCode = 'PAPCA1-1011'
# outfile = infile.replace('.mat', '')
# assert outfile<>infile, 'Output file would overwrite input!'


# load file and extract variables
data = loadmat(infile)
print data['__header__']
spectrum = data['Spectrum']
height, width = spectrum.shape
print height, width

# convert time from datestr(0) in Matlab to datetime
tt = data['Start_time_day'][0,:] - 367  # convert to offset from 0001-01-01
time = []
for t in tt:
    time.append( datetime(1,1,1) + timedelta(t) )


# save chunks of spectrum in images
print 'Creating daily chunks' 
iStart = 0
i = 0
while iStart < width:

    # find end of chunk
    iDate = time[iStart].date()
    iEnd = iStart + 1
    while iEnd < width and time[iEnd].date() == iDate:
        iEnd += 1

    # give it a name and save the image
    chunkName = deploymentCode + '_sp%02d'%i + '.png'
    imsave(chunkName, spectrum[:,iStart:iEnd])

    # print some info for db
    tStart = time[iStart]
    print "  ('%s', '%s', %d, timestamptz '%s UTC')," % (deploymentCode, chunkName, iEnd-iStart, tStart.isoformat(' '))

    # start next chunk
    iStart = iEnd
    i += 1

