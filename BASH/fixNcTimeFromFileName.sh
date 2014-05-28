#!/bin/bash

# test the number of input arguments
if [ $# -ne 1 ]
then
  echo "Usage: $0 ncFile"
  exit
fi

# get the TIME value from file name
timeStr=`echo $1 | cut -f 4 -d '_'`
yearStr=${timeStr:0:4}
monStr=${timeStr:4:2}
dayStr=${timeStr:6:2}
hourStr=${timeStr:9:2}
minStr=${timeStr:11:2}
secStr=${timeStr:13:2}
timeStr=$yearStr"-"$monStr"-"$dayStr"T"$hourStr":"$minStr":"$secStr
timeStrNcdump=$yearStr"-"$monStr"-"$dayStr" "$hourStr":"$minStr

# get the TIME value from variable
timeVal=`ncks -s "%lf" -H -C -F -d TIME,1 -v TIME $1`
timeValNcdump=`ncdump -v TIME -t $1 | grep "TIME = \""`

# time is in seconds since 01-01-1970
timeFileNameVal=`date -u -d "$timeStr" +%s`

# substract number of seconds until 01-01-1950 (reference date)
nSec1950=`date -u -d "1950-01-01 00:00:00 UTC" +%s`
timeFileNameVal=`echo "$timeFileNameVal - $nSec1950" | bc -l`

# transform from seconds to decimal days
# (bc -l calls the math library and enables decimals for divisions)
timeFileNameVal=`echo "$timeFileNameVal / (24 * 3600)" | bc -l`

if [ "$timeStrNcdump" != "$timeValNcdump" ]
then
	ncap2 -h -O -s "TIME(0)=$timeFileNameVal" $1 $1
	echo "$1 fixed from $timeVal to $timeFileNameVal"
fi

timeCoverage=$timeStr"Z"

# check for a global attribute time_coverage_start with value being $timeCoverage
metaNc=`ncdump -h $1 | grep -E -i "time_coverage_start = \"$timeCoverage\""`
if [ -z "$metaNc" ]; then # metaNc is empty
	# update time_coverage_start global attribute
	ncatted -a time_coverage_start,global,o,c,"$timeCoverage" -h $1
	printf "$1 fixed with an updated time_coverage_start = $timeCoverage\n"
fi

# check for a global attribute time_coverage_end with value being $timeCoverage
metaNc=`ncdump -h $1 | grep -E -i "time_coverage_end = \"$timeCoverage\""`
if [ -z "$metaNc" ]; then # metaNc is empty
	# update time_coverage_end global attribute
	ncatted -a time_coverage_end,global,o,c,"$timeCoverage" -h $1
	printf "$1 fixed with an updated time_coverage_end = $timeCoverage\n"
fi
