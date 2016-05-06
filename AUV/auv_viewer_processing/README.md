# AUV DATA PROCESSING
This script will process a new AUV campaign to make it available through the AUV VIEWER, http://auv.aodn.org.au/auv/ as well as the IMOS/AODN portal

## Usage

``` bash
./auv_campaign_download.sh PS201502;                                  # downloads a full campaign to WIP_DIR by performing an rsync (~20 40GB)
./auv_processing.py -p -c $WIP_DIR/AUV/AUV_DOWNLOAD_CAMPAIGN/PS201502 # process the campaign, and push all information to both AUV harvesters, auv viewer and campaign data to S3
```

```bash
# other options
auv_processing.py -h
usage: auv_processing.py [-h] -c CAMPAIGN_PATH [-n] [-p]

optional arguments:
  -h, --help            show this help message and exit
  -c CAMPAIGN_PATH, --campaign-path CAMPAIGN_PATH
                        campaign path
  -n, --no-thumbnail-creation
                        process or reprocess campaign without the creation of
                        thumbnails
  -p, --push-to-incoming
                        push output data, and ALL AUV CAMPAIGN data to
                        incoming dir for pipeline processing

# examples
auv_processing.py -c /tmp/PS201502 -p    # process campaign path and push data to incoming dir
auv_processing.py -c /tmp/PS201502 -p -n # same as above without the creation of thumbnails
```

For each dive, the python script will :
 1. go through all tiff images, and extract individual information with GDAL
 2. read NETCDF files and match data (TEMP, PSAL, OPBS ... ) with data extracted from the images
 3. create a CSV file data output to be loaded in the database using the AUV VIEWER talend harvester. Used for the AUV viewer web app
 4. create a CSV reporting file to be loaded by the talend harvester to the database for reporting
 5. push different type of masnifest files to:
      1. populate the AUV VIEWER
      2. copy the thumbnails to s3 used by the AUV VIEWER
      3. push the NetCDF files to s3 and call the harvester
      4. push ALL dive data to s3 with async-upload.py
      5. push ```all_reports``` folder containing pdf files to s3

In other word, this script handles completely the process of AUV campaign once downloaded to a wip folder.

## RSYNC data from Sydney storage to WIP data storage
see ./auv_campaign_download.sh. Contact stefanw@acfr.usyd.edu.au if access was revoked
The download can only be done from 2 machines (aws 10, nec 10)

## Contact Support
Email: laurent.besnard@utas.edu.au
