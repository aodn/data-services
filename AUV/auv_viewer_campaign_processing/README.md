# AUV DATA PROCESSING


## Usage

Open config.txt to change the list of campaigns to process :
Example :
``` bash
campaignName                  = SEQueensland201310,Tasmania200810,Tasmania200903
```

Execute the program by typing in your shell ```./AUV.sh``` or ```./AUV_fast.sh``` . See explanations below.


__AUV.sh__ will process a new campaign from scratch. For each dive, It will :
 1.  go through all tiff images, and extract individual information with GDAL. A matlab *.mat file is save in the WIP directory for another launch of the program
 2.  read NETCDF files and match the data with data extracted from the images
 3.  create a CSV file output to be loaded in the database using the AUV VIEWER talend harvester. Used for the AUV viewer web app
 4.  create non existing thumbnails used by the AUV viewer web app
 5.  Call AUV_Reporting wich creates a CSV file loaded by the talend harvester to the database for reporting
 6.  rsync data to their respective production folders


__AUV_fast.sh__ will process a new campaign quicker. Assuming this campaign has already been processed. This is a much quicker process to regenerate CSV files used by the Talend harvester (1*) It will , for each Dive :
 1. __NOT__ go through all tiff images to extract individual information with GDAL. A matlab *.mat file is __loaded__ from the WIP directory 
 2. read NETCDF files and match the data with data extracted from the images
 3. create a CSV file output to be loaded in the database using the AUV VIEWER talend harvester. Used for the AUV viewer web app
 4. __DON'T__ create thumbnails
 5.  Call AUV_Reporting wich creates a CSV file loaded by the talend harvester to the database for reporting
 6. rsync data to their respective production folders

(1*) Processing all campaigns could take up to a month. With the _fast version, it would take a few hours.


## RSYNC data from Sydney storage to IMOS data storage
The process is manual, please refer to __AUV_rsync_progress.ods__ which is self explanatory

## Contact Support
Email: laurent.besnard@utas.edu.au
