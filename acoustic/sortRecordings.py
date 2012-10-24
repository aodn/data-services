#! /usr/bin/env python
#
# Sort individual acoustic recording files into daily directories
# based on start times in a Matlab spectrogram file

import sys, os
from scipy.io import loadmat
from matplotlib.pyplot import imsave
from datetime import datetime, timedelta

# get file from command line
if len(sys.argv) < 2:
    print 'usage:\n  '+sys.argv[0]+' infile.mat'
    print '  where infile name is <site_code>-<curtin_id>.mat'
    exit()
infile = sys.argv[1]

siteDep = infile.split('.')[0]
siteCode, curtinID = siteDep.split('-')

archive = '/data/archive/ANMN/Acoustic'
public = os.path.join('/data/public/ANMN/Acoustic', siteCode, curtinID)


# load file and extract variables
data = loadmat(infile)
print data['__header__']
recName = data['File_name']
nRec = len(recName)

# convert time from datestr(0) in Matlab to datetime
tt = data['Start_time_day'][0,:] - 367  # convert to offset from 0001-01-01
time = []
for t in tt:
    time.append( datetime(1,1,1) + timedelta(t) )

# for each recording...
for i in range(nRec):
    name = recName[i]
    dateStr = time[i].strftime('%Y%m%d')

    source = os.path.join(archive, name)
    dest = os.path.join(public, dateStr, 'raw', name)
    print '%s.* -> %s' % (source, dest)

    # os.mkdir(dateStr)

    

