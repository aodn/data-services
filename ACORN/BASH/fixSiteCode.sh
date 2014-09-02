#!/bin/bash

# test the number of input arguments
if [ $# -ne 2 ]
then
  echo "Usage: $0 nc_file.nc site_code"
  exit
fi

ncPath=$1
siteCode=$2

# get the file name without path
ncName=${ncPath##*/}

# check for a global attribute site_code
metaNc=`ncdump -h $ncPath | grep -E -i "site_code"`
if [ ! -z "$metaNc" ]; then # metaNc is not empty
	# check for its value being $siteCode
	metaNc=`ncdump -h $ncPath | grep -E -i "site_code = \"$siteCode\""`
	if [ -z "$metaNc" ]; then # metaNc is empty
		# update site_code global attribute
		# I want the site_code global attribute to be updated
		ncatted -a site_code,global,m,c,"$siteCode" -h $ncPath
		printf "$ncName fixed with an updated site_code = $siteCode\n"
	fi
else
	# create site_code global attribute
	ncatted -a site_code,global,c,c,"$siteCode" -h $ncPath
	printf "$ncName fixed with a new site_code = $siteCode\n"
fi
