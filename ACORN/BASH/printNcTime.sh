#!/bin/bash

# test the number of input arguments
if [ $# -ne 2 ]
then
  echo "Usage: $0 ncFile timeRecord"
  exit
fi

# get the TIME value
timeValue=`ncks -s "%f" -H -C -F -d TIME,$2 -v TIME $1`

# transform from decimal days to rounded seconds
timeValue=`echo "$timeValue * 24 * 3600" | bc`
timeValue=`echo $(printf %.0f $(echo "scale=0;(((10^0)*$timeValue)+0.5)/(10^0)" | bc))`

# add number of seconds until 01-01-1950 (reference date)
nSec1950=`date -u -d "1950-01-01 00:00:00 UTC" +%s`
timeValue=`echo "$timeValue + $nSec1950" | bc`

timeString=`date -u -d "@$timeValue" +%FT%TZ`

echo "$1 : $timeString"
