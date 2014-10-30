#!/bin/bash

 rsyncSourcePath=/mnt/imos-t4/IMOS/staging/SOOP/BA/Processed_data
 
 rsyncRawSourcePath=/mnt/imos-t4/IMOS/staging/SOOP/BA/Raw_data

 rsyncPublicDestinationPath=/mnt/imos-t4/IMOS/public/SOOP/BA
   
 rsyncRawDestinationPath=/mnt/imos-t4/IMOS/archive/SOOP/BA/raw

 rsyncDestinationPath=/mnt/opendap/1/IMOS/opendap/SOOP/SOOP-BA  

# rsync between staging and public : move png's
rsync -avr  --remove-source-files --include '+ */' --include '*.png' --exclude '- *' ${rsyncSourcePath}/ ${rsyncPublicDestinationPath}/;

# rsync between staging and  archive: move raw data
rsync -avr --remove-source-files ${rsyncRawSourcePath}/ ${rsyncRawDestinationPath}/;

# rsync between staging and opendap : move data to opendap 
rsync -avr --remove-source-files --include '+ */' --include '*.nc' --exclude '*.png'  ${rsyncSourcePath}/ ${rsyncDestinationPath}/;
