#!/bin/bash

# test the number of input arguments
if [ $# -ne 1 ]
then
  echo "Usage: $0 file.nc"
  exit
fi

ncPath=$1

# get the file name without path
ncName=${ncPath##*/}

# check for a global attribute with relevant string
metaNcVer=`ncdump -h $ncPath | grep -E -i ':toolbox_version'` | cut -f 2 -d '"'
meta=`ncdump -h $ncPath | grep -E -i 'Author flagged '`
if [ ! -z "$meta" ]; then # meta is not empty
	printf "$ncPath is manually QCed with toolbox version $metaNcVer\n"
fi
