#!/bin/bash

# test the number of input arguments
if [ $# -ne 1 ]
then
  echo "Usage: $0 ncFile"
  exit
fi

# extract file name
ncName=${1##*/}

# get the TIME value from file name
timeStr=`echo $1 | cut -f 4 -d '_'`
yearStr=${timeStr:0:4}
monStr=${timeStr:4:2}
dayStr=${timeStr:6:2}
hourStr=${timeStr:9:2}
minStr=${timeStr:11:2}
secStr=${timeStr:13:2}
timeStr=$yearStr"-"$monStr"-"$dayStr"T"$hourStr":"$minStr":"$secStr"Z"

# get the TIME value from file
timeValue1950days=`ncks -s "%f" -H -C -F -d TIME,1 -v TIME $1`

# transform from decimal days to rounded seconds with 30min added
timeValue1950secondsOriginal=`echo "$timeValue1950days * 24 * 3600" | bc`
timeValue1950secondsOffset=`echo "$timeValue1950days * 24 * 3600 + 30 * 60" | bc`
timeValue1950secondsOriginal=`echo $(printf %.0f $(echo "scale=0;(((10^0)*$timeValue1950secondsOriginal)+0.5)/(10^0)" | bc))`
timeValue1950secondsOffset=`echo $(printf %.0f $(echo "scale=0;(((10^0)*$timeValue1950secondsOffset)+0.5)/(10^0)" | bc))`

timeValue1950daysOffset=`echo "$timeValue1950secondsOffset / (24 * 3600)" | bc -l`

# add number of seconds until 01-01-1950 (reference date)
nSec1950=`date -u -d "1950-01-01 00:00:00 UTC" +%s`
timeValueOriginal=`echo "$timeValue1950secondsOriginal + $nSec1950" | bc`
timeValueOffset=`echo "$timeValue1950secondsOffset + $nSec1950" | bc`

# timeValue is now in seconds since 01-01-1970 (date command reference)
timeStringOriginal=`date -u -d "@$timeValueOriginal" +%FT%TZ`
timeStringOffset=`date -u -d "@$timeValueOffset" +%FT%TZ`

if [ "$timeStringOriginal" != "$timeStr" ]
then
	if [ "$timeStringOffset" = "$timeStr" ]
	then
		# adding 30min offset fix inconsistency
		ncap2 -h -O -s "TIME(0)=$timeValue1950daysOffset" $1 $1
		echo "Time is now $timeStringOffset instead of $timeStringOriginal for $ncName"
	else
		# adding 30min offset doesn't help so print
		echo "Warning : computed $timeStringOffset not consistent with $timeStr in file name $ncName"
	fi
fi
