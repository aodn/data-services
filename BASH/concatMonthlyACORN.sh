#!/bin/bash

# test the number of input arguments
if [ $# -ne 4 ]
then
	echo "Usage: $0 file_version site year month"
	exit
fi

if [ "$1" = "FV00" ]
then
	sourceFolder=$OPENDAP"/ACORN/gridded_1h-avg-current-map_non-QC"
	targetFolder=$OPENDAP"/ACORN/monthly_gridded_1h-avg-current-map_non-QC"
elif [ "$1" = "FV01" ]
then
	sourceFolder=$OPENDAP"/ACORN/gridded_1h-avg-current-map_QC"
	targetFolder=$OPENDAP"/ACORN/monthly_gridded_1h-avg-current-map_QC"
else
	echo "Usage: file_version must either be FV00 or FV01"
	exit
fi

sourceFolder=$sourceFolder"/"$2"/"$3"/"$4
targetFolder=$targetFolder"/"$2"/"$3

# we check that the source directory exists
if [ ! -d "$sourceFolder" ]; then
	echo "Error in $0 $1 $2 $3 $4: folder $sourceFolder does not exist"
	exit
fi

totalTic=$(date +%s.%N)

# concatenated file creation date is taken just before actually listing
# the files that are to be concatenated so that we may compare which are
# the new single files to include in the future in an already existing
# aggregated file.
creationDate=`date -u +%s`

# we concatenate the directory
ncConcatFolder.sh $sourceFolder

tic=$(date +%s.%N)

# we make sure we retrieve a full path
if [ "${sourceFolder:0:1}" = "/" ]
then
	ncPath=$sourceFolder
else
	ncPath=`pwd`"/"$sourceFolder
fi
if [ "${ncPath:${#ncPath}-1:${#ncPath}}" = "/" ]
then
	ncPath=${ncPath:0:${#ncPath}-1}
fi
ncPath=$ncPath".nc"

# separate the file name and path
ncName=${ncPath##*/}
path=${ncPath%/*}

# get the title global attribute
metaTitle=`ncks -M $ncPath | grep -E -i "attribute [0-9]*: title" | cut -f 11- -d ' ' | sort`

# get the TIME dimension size
metaSizeTIME=`ncks -m -v TIME $ncPath | grep -E -i ": TIME, size =" | cut -f 7 -d ' ' | sort`

# get the TIME values
start=`ncks -s "%f" -H -F -C -d TIME,1 -v TIME $ncPath`
end=`ncks -s "%f" -H -F -C -d TIME,$metaSizeTIME -v TIME $ncPath`

# transform from decimal days to rounded seconds
start=`echo "$start * 24 * 3600" | bc`
start=`echo $(printf %.0f $(echo "scale=0;(((10^0)*$start)+0.5)/(10^0)" | bc))`
end=`echo "$end * 24 * 3600" | bc`
end=`echo $(printf %.0f $(echo "scale=0;(((10^0)*$end)+0.5)/(10^0)" | bc))`

# add number of seconds until 01-01-1950 (reference date)
nSec1950=`date -u -d "1950-01-01 00:00:00 UTC" +%s`
start=`echo "$start + $nSec1950" | bc`
end=`echo "$end + $nSec1950" | bc`

metaYear=`date -u -d "@$start" +%Y`
metaMonth=`date -u -d "@$start" +%m`

startCoverage=`echo "$start - (30 * 60)" | bc`
endCoverage=`echo "$end + (30 * 60)" | bc`

startAtt=`date -u -d "@$start" +%FT%TZ`
endAtt=`date -u -d "@$end" +%FT%TZ`

startFileName=`date -u -d "@$start" +%Y%m%dT%H%M%SZ`
endFileName=`date -u -d "@$end" +%Y%m%dT%H%M%SZ`

startCoverageAtt=`date -u -d "@$startCoverage" +%FT%TZ`
endCoverageAtt=`date -u -d "@$endCoverage" +%FT%TZ`

creationAtt=`date -u -d "@$creationDate" +%FT%TZ`
creationFileName=`date -u -d "@$creationDate" +%Y%m%dT%H%M%SZ`

# update the title, time coverage and creation date global attributes
metaTitle=${metaTitle%,*}
metaTitle="$metaTitle, from $startAtt to $endAtt"
ncatted -a title,global,m,c,"""$metaTitle""" -h $ncPath
ncatted -a time_coverage_start,global,m,c,$startCoverageAtt -h $ncPath
ncatted -a time_coverage_end,global,m,c,$endCoverageAtt -h $ncPath
ncatted -a date_created,global,m,c,$creationAtt -h $ncPath

# generate netcdf file name
newFileName="IMOS_ACORN_V_"$startFileName"_"$2"_"$1"_monthly-1-hour-avg_END-"$endFileName"_C-"$creationFileName".nc"

# we check that the target directory exist
if [ ! -d "$targetFolder" ]; then
	mkdir -p $targetFolder
fi

mv $ncPath "$targetFolder/$newFileName"

toc=$(date +%s.%N)

printf "$newFileName created: \t%.1Fs\n"  $(echo "$toc - $tic"|bc )

tic=$(date +%s.%N)

# we delete any pre-existing monthly aggregated zipped file
oldFileNames="$targetFolder""/IMOS_ACORN_V_""$3""$4""*.nc.gz"
rm -fv $oldFileNames

gzip -f "$targetFolder/$newFileName"

toc=$(date +%s.%N)

printf "%.1Fs\t\tRelevant file has been zipped and replaced\n"  $(echo "$toc - $tic"|bc )

totalToc=$(date +%s.%N)

printf "%.1Fs\t\tTotal time\n\n"  $(echo "$totalToc - $totalTic"|bc )

