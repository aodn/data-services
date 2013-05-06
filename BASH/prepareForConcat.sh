#!/bin/bash

# test the number of input arguments
if [ $# -ne 1 ]
then
  echo "Usage: $0 netcdf_file.nc"
  exit
fi

ncName=$1

## check for a TIME dimension being a record
#metaTIME=`ncks -m -v TIME $ncName | grep -E -i "TIME dimension [0-9]*: TIME, size = [0-9]* #NC_DOUBLE, dim. ID = [0-9]* " | cut -f 13- -d ' ' | sort`
#if [ "$metaTIME" != "(CRD)(REC)" ]
#then
#	# we make the TIME dimension a record dimension
#	ncks -h -O --mk_rec_dmn TIME $ncName $ncName
#fi

# check for a TIME dimension being unlimited
metaTIME=`ncdump -h $ncName | grep -E -i "TIME = UNLIMITED"`
if [ -z "$metaTIME" ]
then
	# we make the dimension unlimited 
	# (any variable function of this dimension will become a record variable)
	str1='TIME = 1 ;'
	str2='TIME = UNLIMITED ; // (1 currently)'
	ncdump $ncName | sed -e "s#^.$str1# $str2#" | ncgen -o "$ncName.tmp"
	mv "$ncName.tmp" $ncName
fi
