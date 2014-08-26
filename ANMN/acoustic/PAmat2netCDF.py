#! /usr/bin/env python
#
# Read in a Matlab file containing a spectrogram and convert it to an
# IMOS netCDF file.

from optparse import OptionParser
from scipy.io import loadmat
from IMOSfile.IMOSnetCDF import IMOSnetCDFFile


# get file from command line
parser = OptionParser()
options, args = parser.parse_args()
infile = args[0]
if len(args)>1: outfile = args[1]
else: outfile = infile.replace('.mat', '.nc')
assert outfile<>infile, 'Output file would overwrite input!'

# load file and extract variables
data = loadmat(infile)
print data['__header__']

fname = data['File_name']
spectrum = data['Spectrum'].transpose()
frequency = data['Frequency'][:,0]
time = data['Start_time_day'][0,:] - 1949 * 365.242199


# create new netCDF file
F = IMOSnetCDFFile(outfile)

# add dimensions
vtime = F.setDimension('TIME', time)

vfreq = F.setDimension('FREQUENCY', frequency)
vfreq.standard_name='frequency' 
vfreq.long_name='frequency'
vfreq.units='Hz'
vfreq.axis='Z'
vfreq.valid_min = 0
vfreq.valid_max = 90000.0


# add spectrum data
vspec = F.createVariable('PSD', spectrum.dtype.char, ('TIME', 'FREQUENCY'))
vspec[:] = spectrum
vspec.long_name='power spectrum density of sea noise'
vspec.units='dB (re 1mPa)'
vspec.valid_min = 0
# vspec.valid_max = 


# write file
F.updateAttributes()
F.close()
