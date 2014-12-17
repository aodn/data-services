#!/bin/bash
#this script execute an rsync between staging and archive after uptading realtime data on opendap
## this part of the code reads  the config.txt
configfile=config.txt

ii=0
while read line; do
if [[ "$line" =~ ^[^#]*= ]]; then
        name[ii]=`echo $line | cut -d'=' -f 1`
        value[ii]=`echo $line | cut -d'=' -f 2-`
        ((ii++))
fi

done <$configfile

# this part of the code finds the script.path value in the config.txt
for (( jj = 0 ; jj < ${#value[@]} ; jj++ ));
do
    if [[ "${name[jj]}" =~ "SOURCE_PATH" ]] ; then
         SOURCE=${value[jj]} ;   
    fi

    if [[ "${name[jj]}" =~ "DEST_ARCHIVE_PATH" ]] ; then
         ARCHIVE=${value[jj]} ;    
    fi
done 

# rsyncing now
rsync -vr --min-size=1 --remove-source-files --include '+ */' --include '*.nc' --exclude '- *' ${SOURCE}/ ${ARCHIVE}/