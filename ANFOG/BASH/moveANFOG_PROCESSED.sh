#!/bin/bash
#move NetCDF file to opendap
rsync -aR -O --remove-source-files /mnt/imos-t4/IMOS/staging/ANFOG/processed/seaglider/./ /mnt/opendap/1/IMOS/opendap/ANFOG/seaglider
rsync -aR -O --remove-source-files /mnt/imos-t4/IMOS/staging/ANFOG/processed/slocum_glider/./ /mnt/opendap/1/IMOS/opendap/ANFOG/slocum_glider
#move jpeg and kml to public
rsync -aR -O --remove-source-files /mnt/imos-t4/IMOS/staging/ANFOG/jpeg/seaglider/./ /mnt/imos-t4/IMOS/public/ANFOG/seaglider
rsync -aR -O --remove-source-files /mnt/imos-t4/IMOS/staging/ANFOG/jpeg/slocum_glider/./ /mnt/imos-t4/IMOS/public/ANFOG/slocum_glider
