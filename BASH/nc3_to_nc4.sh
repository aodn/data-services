#!/bin/bash

# test the number of input arguments
if [ $# -ne 1 ]
then
  echo "Usage: $0 netcdf3_file.nc"
  exit
fi

tic=$(date +%s.%N)

ncPath=$1

# get the file name without path
ncName=${ncPath##*/}

# check for a global attribute netcdf_version being 3.6
metaNcVer=`ncdump -h $ncName | grep -E -i 'netcdf_version = "3.6"'`
if [ ! -z "$metaNcVer" ]; then # metaNcVer is not empty
	# convert to NetCDF4 with nco's Lempel-Ziv lossless compression level set to 5 (between 0 and 9)
	# I don't want the history global attribute to be updated and I force overwriting the output file
	# (note that output file == input file is possible in nco)
	ncks -4 -L 5 -h -O $ncPath $ncPath

	# retrieve current NetCDF API's version
	ncVersion=`nc-config --version | awk '{print $2}'`

	# update netcdf_version global attribute
	# I don't want the history global attribute to be updated
	ncatted -a netcdf_version,global,m,c,$ncVersion -h $ncPath
fi

toc=$(date +%s.%N)

printf "%6.1Fs\t$ncName converted to NetCDF4\n"  $(echo "$toc - $tic"|bc )
