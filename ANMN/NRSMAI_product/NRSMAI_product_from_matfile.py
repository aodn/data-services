#! /usr/bin/env python
#
# Read in the data products from the Matlab file created by Ken
# Ridgway's scripts and write them to IMOS netCDF files.


import os
import sys
import argparse
import numpy as np
from numpy.ma import MaskedArray
from scipy.io import loadmat
from datetime import datetime, timedelta
import IMOSnetCDF as inc


### Hard-coded values

# attributes file for netCDF
source_path = os.path.dirname(os.path.realpath(__file__))
attrib_file = os.path.join(source_path, 'NRSMAI_product.attr')

# epoch for time values in Matlab input file
input_epoch = datetime(1900,1,1)

# epoch for output netCDF file
inc.epoch = datetime(1950,1,1)
output_epoch = inc.epoch

# depth levels
depth = np.arange(0., 60., 10.)

# data code and product names for output files
data_code = 'STZ'
product_name_original     = 'NRSMAI-long-timeseries'
product_name_interpolated = 'NRSMAI-long-timeseries-interpolated'


### Parse command-line arguments
parser = argparse.ArgumentParser()
parser.add_argument('matfile', help='input Matlab file')
args = parser.parse_args()


### Read in variables from mat file
data = loadmat(args.matfile, squeeze_me=True)
tem_mar = MaskedArray(data['tem_mar'], mask=np.isnan(data['tem_mar']))
sal_mar = MaskedArray(data['sal_mar'], mask=np.isnan(data['sal_mar']))
tem_mi = MaskedArray(data['tem_mi'], mask=np.isnan(data['tem_mi']))
sal_mi = MaskedArray(data['sal_mi'], mask=np.isnan(data['sal_mi']))

# convert time variables to days from our chosen epoch
dt = input_epoch - output_epoch    # difference as a timedelta object
dt = dt.total_seconds()/24./3600.  # difference in decimal days

time_mar_t = data['time_mar_t'] + dt
time_mar_s = data['time_mar_s'] + dt
time_mi = data['time_mi'] + dt


### Put original sampling variables onto a common time dimension

# Create a single time variable
time_set_t = set(time_mar_t)
time_set_s = set(time_mar_s)
time_set_all = set.union(time_set_t, time_set_s) # set of all unique timestamps
time = list(time_set_all)
time.sort()

# Find indices to map temp & sal measurements onto this time dimension
index_t = []
index_s = []
for tt in time_mar_t:
    index_t.append(time.index(tt))
for tt in time_mar_s:
    index_s.append(time.index(tt))


### Create netCDF file for original sampling times
nc_orig = inc.IMOSnetCDFFile(attribFile=attrib_file)

TIMESERIES =  nc_orig.createVariable('TIMESERIES', np.int32, ())
TIMESERIES[:] = 1

TIME = nc_orig.setDimension('TIME', time)
TIME.units = output_epoch.strftime('days since %Y-%m-%d %H:%M:%S UTC')
TIME.comment = "Where only the sampling date is available, a UTC time of 00:00 is assumed."

DEPTH = nc_orig.setDimension('DEPTH', depth)

LATITUDE = nc_orig.setVariable('LATITUDE', nc_orig.geospatial_lat_min, ())
LONGITUDE = nc_orig.setVariable('LONGITUDE', nc_orig.geospatial_lon_min, ())

TEMP = nc_orig.createVariable('TEMP', tem_mar.dtype, ('TIME','DEPTH'))
TEMP[index_t,:] = tem_mar
TEMP.coordinates = 'TIME DEPTH LATITUDE LONGITUDE'

PSAL = nc_orig.createVariable('PSAL', sal_mar.dtype, ('TIME','DEPTH'))
PSAL[index_s,:] = sal_mar
PSAL.coordinates = 'TIME DEPTH LATITUDE LONGITUDE'

nc_orig.geospatial_vertical_min = min(depth)
nc_orig.geospatial_vertical_max = max(depth)
nc_orig.updateAttributes()
savedFile = nc_orig.standardFileName(datacode=data_code, product=product_name_original)
print savedFile

nc_orig.close()


### Create netCDF for interpolated timeseries
nc_interp = inc.IMOSnetCDFFile(attribFile=attrib_file)

TIMESERIES =  nc_interp.createVariable('TIMESERIES', np.int32, ())
TIMESERIES[:] = 1

TIME = nc_interp.setDimension('TIME', time_mi)
TIME.units = output_epoch.strftime('days since %Y-%m-%d %H:%M:%S UTC')
DEPTH = nc_interp.setDimension('DEPTH', depth)

LATITUDE = nc_interp.setVariable('LATITUDE', nc_interp.geospatial_lat_min, ())
LONGITUDE = nc_interp.setVariable('LONGITUDE', nc_interp.geospatial_lon_min, ())

TEMP = nc_interp.createVariable('TEMP', np.float32, ('TIME','DEPTH'))
TEMP[:] = tem_mi
TEMP.coordinates = 'TIME DEPTH LATITUDE LONGITUDE'

PSAL = nc_interp.createVariable('PSAL', np.float32, ('TIME','DEPTH'))
PSAL[:] = sal_mi
PSAL.coordinates = 'TIME DEPTH LATITUDE LONGITUDE'

nc_interp.geospatial_vertical_min = min(depth)
nc_interp.geospatial_vertical_max = max(depth)
nc_interp.updateAttributes()
savedFile = nc_interp.standardFileName(datacode=data_code, product=product_name_interpolated)
print savedFile

nc_interp.close()
