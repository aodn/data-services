#!/bin/bash

rsyncSourcePath=/mnt/imos-t4/IMOS/staging/ANFOG/processed
    
rsyncImagesSourcePath=/mnt/imos-t4/IMOS/staging/ANFOG/jpeg
        
rsyncRawSourcePath=/mnt/imos-t4/IMOS/staging/ANFOG/raw
             
rsyncPublicDestinationPath=/mnt/imos-t4/IMOS/public/ANFOG
            
rsyncArchiveDestinationPath=/mnt/imos-t4/IMOS/archive/ANFOG
          
rsyncDestinationPath=/mnt/opendap/1/IMOS/opendap/ANFOG   
      

# rsync between staging and opendap : move data to opendap 
rsync -avr -O --remove-source-files ${rsyncSourcePath}/seaglider/ ${rsyncDestinationPath}/seaglider/;
rsync -avr -O --remove-source-files ${rsyncSourcePath}/slocum_glider/ ${rsyncDestinationPath}/slocum_glider/;

# rsync between staging and public : move images and kml to public
rsync -ar -O --remove-source-files ${rsyncImagesSourcePath}/seaglider/ ${rsyncPublicDestinationPath}/seaglider/;
rsync -ar -O --remove-source-files ${rsyncImagesSourcePath}/slocum_glider/ ${rsyncPublicDestinationPath}/slocum_glider/;

# rsync between staging and archive : move raw to archive
rsync -ar -O --remove-source-files ${rsyncRawSourcePath}/seaglider/ ${rsyncArchiveDestinationPath}/seaglider/;
rsync -ar -O --remove-source-files ${rsyncRawSourcePath}/slocum_glider/ ${rsyncArchiveDestinationPath}/slocum_glider/;  









