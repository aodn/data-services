#!/bin/bash

# test the number of input arguments
if [ $# -ne 1 ]
then
  echo "Usage: $0 netcdf4_file.nc"
  exit
fi

tic=$(date +%s.%N)

ncPath=$1

# get the file name without path
ncName=${ncPath##*/}

# convert to NetCDF3 CLASSIC
# I don't want the history global attribute to be updated and I force overwriting the output file
# (note that output file == input file is possible in nco)
ncks -3 -h -O $ncPath $ncPath

# retrieve current NetCDF API's version
ncVersion="3.6"

# update netcdf_version global attribute
# I don't want the history global attribute to be updated
ncatted -a netcdf_version,global,m,c,$ncVersion -h $ncPath

toc=$(date +%s.%N)

printf "%.1Fs\t\t$ncName converted to NetCDF3 CLASSIC\n"  $(echo "$toc - $tic"|bc )
