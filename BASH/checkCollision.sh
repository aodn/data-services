#!/bin/bash

# test the number of input arguments
if [ $# -ne 1 ]
then
	echo "Usage: $0 directory"
	exit
fi

# we make sure we retrieve a full path
if [ "${1:0:1}" = "/" ]
then
	sourceFolder=$1
else
	sourceFolder=`pwd`"/"$1
fi
if [ "${sourceFolder:${#sourceFolder}-1:${#sourceFolder}}" = "/" ]
then
	sourceFolder=${sourceFolder:0:${#sourceFolder}-1}
fi

# we check that the source directory exists
if [ ! -d "$sourceFolder" ]; then
	echo "Error in $0 $1: folder $sourceFolder does not exist"
	exit
fi

#find $sourceFolder -type f -name '*.nc.*' -print0 | sort -z | xargs -0 -I {} getInfoCollision.sh {}
find $sourceFolder -type f -name '*.nc.*' -print0 | sort -z | xargs -0 -I {} fixCollision.sh {}
