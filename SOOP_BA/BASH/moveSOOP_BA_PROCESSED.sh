#!/bin/bash
# move png to public
rsync -avR --remove-source-files --include '+ */' --include '*.png' --exclude '- *' /mnt/imos-t4/IMOS/staging/SOOP/BA/Processed_data/./ /mnt/imos-t4/IMOS/public/SOOP/BA/
# move data to opendap 
rsync -avR --remove-source-files --include '+ */' --include '*.nc' --exclude '*.png'  /mnt/imos-t4/IMOS/staging/SOOP/BA/Processed_data/./ /mnt/opendap/1/IMOS/opendap/SOOP/SOOP-BA/
