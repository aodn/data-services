#!/bin/bash

rsyncSourcePath=/mnt/imos-t4/IMOS/staging/ANFOG/realtime
            
rsyncPublicDestinationPath=/mnt/imos-t4/IMOS/public/ANFOG/Realtime
             
rsyncArchiveDestinationPath=/mnt/imos-t4/IMOS/archive/ANFOG/realtime
         
rsyncDestinationPath=/mnt/opendap/1/IMOS/opendap/ANFOG/ANFOG/REALTIME
   
# rsync between staging and archive : move seaglider comm.log files
rsync -avr --remove-source-files --include '+ */' --include '*.log' --exclude '- *' ${rsyncSourcePath}/seaglider/ ${rsyncARCHIVEDestinationPath}/seaglider/;

# rsync between staging and public : move png's
rsync -avr  --remove-source-files --include '+ */' --include '*.png' --exclude '- *' ${rsyncSourcePath}/ ${rsyncPublicDestinationPath}/;

# rsync between staging and opendap : move data to opendap 
rsync -avr --min-size=1 --remove-source-files --include '+ */' --include '*.nc' --exclude '- *'  ${rsyncSourcePath}/ ${rsyncDestinationPath}/;
