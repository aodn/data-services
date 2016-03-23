#!/bin/bash
# script to loop through realtime subdirectories to find new netcdf files
# then zip related files together
INCOMING_RT=$INCOMING_DIR/ANFOG/realtime

for file in `find $INCOMING_RT/. -iname "*FV0*.nc"`; do

     fileNc=$file
     zipName=`dirname $file`/"`basename $file .nc`.zip"
     
     targetdir=`dirname $file`
     for targetfile in `ls $targetdir`; do
       f="$targetdir/`basename $targetfile`"
       zip $zipName $f
    done
    mv $zipName $INCOMING_RT/ 
    rm $targetdir/*.*    
done
