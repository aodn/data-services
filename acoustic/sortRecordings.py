#! /usr/bin/env python
#
# Sort individual acoustic recording files into daily directories
# based on start times in a Matlab spectrogram file

import sys, os
from scipy.io import loadmat
from matplotlib.pyplot import imsave
from datetime import datetime, timedelta

# get file from command line
if len(sys.argv) < 3:
    print 'usage:\n  '+sys.argv[0]+' infile.mat archive_dir'
    print '  where infile name is <site_code>-<curtin_id>.mat'
    exit()
infile = sys.argv[1]
archive = sys.argv[2]

siteDep = infile.split('.')[0]
siteCode, curtinID = siteDep.split('-')

public = os.path.join('/data/public/ANMN/Acoustic', siteCode, curtinID)

cmd = 'mv -nv'
ext = '.DAT'

# load file and extract variables
data = loadmat(infile)
recName = data['File_name']
nRec = len(recName)

# convert time from datestr(0) in Matlab to datetime
tt = data['Start_time_day'][0,:] - 367  # convert to offset from 0001-01-01
time = []
for t in tt:
    time.append( datetime(1,1,1) + timedelta(t) )

# change to archive directory
print 'cd ' + archive
print 'echo ' + archive

lastDate = ''

# for each recording...
for i in range(nRec):
    name = recName[i] + ext
    dateStr = time[i].strftime('%Y%m%d')

    # create destination directory if need be
    if dateStr <> lastDate:
        dest = os.path.join(public, dateStr, 'raw')
        print '\nmkdir -pv ' + dest
        lastDate = dateStr

    print '%s  %s  %s' % (cmd, name, dest)


    

