#!/bin/bash

# test the number of input arguments
if [ $# -ne 1 ]
then
  echo "Usage: $0 netcdf3_file.gz"
  exit
fi

tic=$(date +%s.%N)

gzName=$1

# deletes the shortest match of '.gz' from back of gzName
ncName=${gzName%.gz}

# force decompress the .gz to .nc and conserve .gz
gzip -fdc $gzName > $ncName

toc=$(date +%s.%N)

printf "%.1Fs\t$gzName unzipped\n"  $(echo "$toc - $tic"|bc )

# convert to NetCDF4
nc3_to_nc4.sh $ncName
