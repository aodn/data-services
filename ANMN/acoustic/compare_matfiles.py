from scipy.io import loadmat
from datetime import datetime, timedelta
from datetime import date
import numpy as np
import os

#filepath  = '/seagate/archive/PAPCA/2823_leftovers__'
filepath  = './'

### start times file
pipe = os.popen('find %s -name "*start_times*"' % filepath)
start_times_file = pipe.readline().strip()
pipe.close()
print 'Start_Times file ', start_times_file

data = loadmat(start_times_file)

tt = data['Start_times']['time'][0,0][:,0] - 367.
st = []
for t in tt: 
    st.append( datetime(1,1,1) + timedelta(t) )
start = np.array(st)


fname = data['Start_times']['file_name'][0,0][:,0]
bla = []
for f in fname: 
    bla.append ( f[0] )
fname = np.array(bla )

print len(start), ' files'



### spectrogram file

pipe = os.popen('find %s -name "*spectrogram*"' % filepath)
spectrogram_file = pipe.readline().strip()
pipe.close()
print 'Spectrogram file ', spectrogram_file

specdata = loadmat(spectrogram_file)

tt = specdata['Start_time_day'][0,:] - 367
nRec = len(tt)
print nRec, ' spectrogram elements'

sstart = []
for t in tt: 
    dt = max( timedelta(t),  datetime(1900,1,1) - datetime(1,1,1)  )
    sstart.append( datetime(1,1,1) + dt )
sstart = np.array(sstart )

sfname = specdata['File_name']



### compare filenames
for i in range(nRec):
    diff = False
    line = '%5d  %s  ' % (i, start[i].strftime('%Y-%m-%d %H:%M'))
    if (start[i] != sstart[i]):
        line += sstart[i].strftime('%Y-%m-%d %H:%M  ')
        diff = True
    else:
        line += ' '*18
    if (fname[i] != sfname[i]):
        line += '%10s%10s' % (fname[i], sfname[i])
        diff = True
    if diff:
        print line







#### stuff... #####################################################################
if False:

    for t, f in zip(st, fname ):
        if t.date() == date(2009, 10, 9):
            os.system( "sed '2p;d' %s.DAT" % f )

    dates = []
    files = []
    for t, f in zip(st, fname ):
        if t.date() == date(2009, 10, 9):
            dates.append(t)
            files.append(f[0][0])
    for f in files:
        os.system( "sed '2p;d' /seagate/public/PAPCA/2823/20090719/raw/%s.DAT" % f )

