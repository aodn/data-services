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

## Installation (temporary)

### option 1
python-gdal on debian can be installed. however this creates a conflict with POSTGIS2.1

### option 2
```
sudo apt-get install gdal-bin
sudo apt-get install libgdal-dev libgdal1h

sudo pip install GDAL==$(gdal-config --version) --global-option=build_ext --global-option="-I/usr/include/gdal" 
```

### option 3 (no root credentials)

Install in the $HOME dir gdal libs and dependencies
```
## AUV virtual env
AUV_VENV_PATH=$HOME/auv_venv
mkdir $AUV_VENV_PATH && cd $AUV_VENV_PATH
# pip freeze > $AUV_VENV_PATH/requirements_host  # should be fine without

# install in $HOME gdal-bin from source
wget http://download.osgeo.org/gdal/1.11.0/gdal-1.11.0.tar.gz
tar -xzvf gdal-1.11.0.tar.gz
cd gdal-1.11.0
./configure --prefix=$HOME
make
make install

# install in $HOME libproj-dev from source
cd $AUV_VENV_PATH;
apt-get source libproj-dev;
cd proj-4.*;
./configure --prefix=$HOME
make;
make install;

# export required path
export PATH="$PATH:$HOME/bin";
export LD_PRELOAD="$HOME/lib/libgdal.so.1";
export LD_LIBRARY_PATH=/lib:/usr/lib:/usr/local/lib:$HOME/lib;

# creation of a python virtual env to install required pip modules
cd $AUV_VENV_PATH;
virtualenv venv;
source venv/bin/activate;

cd $DATA_SERVICES_DIR
pip install numpy
pip install -r requirements.txt
pip install GDAL==$(gdal-config --version) --global-option=build_ext --global-option="-I/$HOME/include/gdal"
```


## Contact Support
Email: laurent.besnard@utas.edu.au
