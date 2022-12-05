# AUV DATA PROCESSING

## Overview
The Autonomous Underwater Vehicle (AUV) is an IMOS facility. AUVs are effective for rapid and cost-effective high-resolution, accurately geo-referenced and targeted acoustic imagery of the seafloor.
The submersible is equipped with a full suite of oceanographic sensors:
* high resolution stereo camera pair and strobes
* multibeam sonar
* depth sensor (Paroscientific)
* Doppler Velocity Log (DVL) including a compass with integrated roll and pitch sensors
* Ultra Short Baseline Acoustic Positioning System (USBL), forward looking obstacle avoidance sonar
* conductivity/temperature sensor (Sea-Bird SBE 37-SIP)
* combination fluorometer/scattering sensor (WET Labs ECO Puck Triplet Sensor) to measure chlorophyll-a, CDOM and turbidity

The AUV facility has performed over the years repeated campaigns all around Australia. 
For each campaign, individual dives around a same location are undertaken.
The number of dives as well as the amount of data collected varies greatly between campaigns, ranging between 5 dives to almost 30 at times.

Once a new campaign is finished and processed by the AUV facility, it is made available on an ACFR USYD server for download and ingestion by AODN.

## Data collected during a Campaign
For each campaign, the dataset is available as a folder hierarchy which is typically found as follows (each type of data is in a different subfolder):

* campaign_name folder:
  * dive_name_number:
    * i*_gtif (contains geotiff versions of all images).
      AUV GeoTiff images are steoroscopic and come as pairs: left-right, forward-backward...
      A GeoTiff contains geolocation only information for each corner of an image.
      see [example](https://s3-ap-southeast-2.amazonaws.com/imos-data/IMOS/AUV/SEQueensland201907/r20190725_224217_SS04_hendersonSth_broad/i20190725_224217_gtif/PR_20190725_224714_932_LC16.tif)
    * i*_subsampN (subsampled geotif images
    * hydro_netcdf (*.nc files, netcdf files containing CT and ecopuck data)
      see [example](http://imos-data.s3-website-ap-southeast-2.amazonaws.com/?prefix=IMOS/AUV/SEQueensland201907/r20190725_224217_SS04_hendersonSth_broad/hydro_netcdf/)
    * track_files (dive track in csv, kml and arcgis shape file format)
      Each dive contains a CSV file listing essential information about every single Geotiff:
        * time/date
        * depth
        * roll/pitch
        * label (Image labels denote the class or cluster assigned to an image)
        see [example](https://s3-ap-southeast-2.amazonaws.com/imos-data/IMOS/AUV/SEQueensland201907/r20190725_224217_SS04_hendersonSth_broad/track_files/SS04_hendersonSth_broad_latlong.csv)
    * mesh (3D reconstuction of the dive)
    * multibeam (a number of different versions of the multibeam product)
      * *.gsf: Navigated and automatically cleaned swath, bathymetry with raw intensity data
      * *.grd: Gridded bathymetry
      * *.grd.pdf: Plotted gridded bathymetry (local northings and eastings)
  * all_reports folder:
    This folder contains the PDF short dive report files, one for each of the dives. These contain some summary graphs and sample images.

see [dive example](http://imos-data.s3-website-ap-southeast-2.amazonaws.com/?prefix=IMOS/AUV/SEQueensland201907/r20190725_224217_SS04_hendersonSth_broad/)

## Dive Size

The following table is an attempt at giving some numbers on the expected size for each dive. 
Pre 2020, the range of values is pretty confident.
Post 2020 and beyond, we have very little data to know what to expect in terms of size range for each dive.
However it seems like new dives have a factor of 10 to 15 times greater that the previous generation of dive. (low confidence)

|                     | number dives | dive size          |  number of pair of pictures | Picture Pixel size | picture size |
|---------------------|--------------|--------------------|-----------------------------|--------------------|--------------|
| campaigns pre 2020  | 5 < n < 30   | 25Gb <size < 80Gb+         | 5 000 > 20 000              | 1.2 Megapixel      | < 1Mb        |
| campaigns post 2020 | 5 < n < 30   | 300Gb < size <  1Tb | 5 000 > 20 000              | 5 and 12 Mp        | ~ 12 Mb      |

## Description of the current workflow
Once a campaign is fully processed by the facility, an informative email is sent to an AODN project officer and the campaign is then ready for ingestion. 

There are currently two main scripts to make an AUV campaign available on both the [AUV viewer](http://auv.aodn.org.au/auv) as well as the [AODN portal AUV collection](https://portal.aodn.org.au/search?uuid=af5d0ff9-bb9c-4b7c-a63c-854a630b6984):
* bash script which rsync a full campaign from the AUV server to ```pipeline-prod-aws-syd``` $WIP_DIR
* python script iterating through individual dives within a campaign which creates various manifest files to be used by python-aodndata [AUV handler](https://github.com/aodn/python-aodndata/blob/master/aodndata/auv/handler.py) 

The description of these two scripts is described below.

### 1) Campaign download

The download of each campaign is done on ```pipeline-prod-aws-syd``` as the projectofficer user.

```bash
cd $DATA_SERVICES_DIR/AUV/auv_viewer_processing
./auv_campaign_download.sh PS201502;                                  # downloads a full campaign to $WIP_DIR by performing an rsync (up to 200GB), Need to be done with projectofficer user for permissions
./auv_processing.py -p -c $WIP_DIR/AUV/AUV_DOWNLOAD_CAMPAIGN/PS201502 # process the campaign, and push all information to both AUV harvesters, auv viewer and campaign data to S3
```

Contact stefanw@acfr.usyd.edu.au if access was revoked
The download can only be done from 2 machines (```pipeline-prod-aws-syd```, ```archive-prod-nec-hob```)

Prior to 2020, it has never been necessary to know in advance the size of campaigns prior to their download. 
Only a handful of times has this been an issue, filling up all the storage available on $WIP_DIR. The reason was always because other old files were left and forgotten filling up the storage.

In order to know in advance the size of campaigns/dives, the script could be improved to include a rsync --dry-run first, and grep the size of each dive prior to their download. There is no other known way to have this information
except if the facility provides this information by email.

### 2) Campaign/Dive processing

The processing of a campaign is done on the same machine with the same user as above.

```bash
cd $DATA_SERVICES_DIR/AUV/auv_viewer_processing

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

The python script currently processes all dives found in a campaign folder through simple iteration.
For each dive, the python script will:
 1. Check the existence of NetCDF, Geotiffs, CSV track files. The script was written with the assumption to have all those different files/products in order to match their data together.
 2. GeoTiff Images:
    a. go through all tiff images, extract individual Geolocation information with GDAL into a Python dictionnary and compute values such as image size...
    b. convert all tiff images into thumbnails size for faster loading by the auv viewer and squiddle
 3. Read the CSV track file
    a. perform a series of check such as the validity of the CSV track file, suc as checking if a Geotiff file is properly included in the CSV file... 
    b. match information found in CSV file (cluster tag, lat, lon, time, image order ...) for each Geotiff with the previous python dictionnary
 4. parse NETCDF files and match data (TEMP, PSAL, OPBS ... ) with Geotiff sampled at the closest time (sample rate is different)
 5. create a CSV file data output from the matched data to be loaded into the database by the AUV VIEWER talend harvester -> Used by the AUV viewer web app as well as Squiddle
 6. create a CSV reporting file to be loaded by the talend harvester to the database for reporting
 7. create various manifest files per dive/per type of files to push, and copy to the $INCOMING_DIRECTORY to be used by the pipeline v2
        1- manifest containing links to netcdf files (ST and B) -> triggering the AUV harvester for the AODN portal
        2- manifest containing links to both DATA_... csv output file. Files used by the AUV viewer and Squiddle -> triggering the AUV viewer harvester
        3- manifest containing links to all generated thumbnails -> async upload, used by the AUV viewer and squiddle
        4- manifest containing link to the full dive folder (minus data already pushed)-> async upload
        5- manifest containing link to the pdf report file -> AUV harvester

In other word, this script handles completely the process of an AUV campaign in an automated way without any user input once a campaign has been downloaded to the $WIP_DIR folder.

## Contact Support
Email: laurent.besnard@utas.edu.au
