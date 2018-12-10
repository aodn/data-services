Dept. Of Transport of Western Australia - Wave dataset
=============

## AWAC instrument

Converts wave, tide, status, current and temperature data from the Dept. of Transport WA into NetCDF files.
This dataset was collected using a AWAC Nortek 1mhz instrument.


#### Using the Script
```bash
usage: wa_awac_process.py [-h] [-o OUTPUT_PATH]

Creates FV01 NetCDF files (WAVE, TIDES...) from full WA AWAC dataset. Prints
out the path of the new locally generated FV01 file.

optional arguments:
  -h, --help            show this help message and exit
  -o OUTPUT_PATH, --output-path OUTPUT_PATH
                        output directory of FV01 netcdf file. (Optional)

```

#### Location of Original Dataset

The dataset was previously downloaded and archived to ```$ARCHIVE_DIR/AODN/Dept-Of-Transport_WA_WAVES```
However the most up to date dataset is found via the kml file (link above)

## Waverider instrument: dataset parser description
### a. Introduction
Waverider buoys have been deployed along the coast of Western Australia by the Department of Transport since 1974. A 
total of 50 sites exists:
* 43 sites are historic ones with no on-going data
* 7 sites are current ones with on-going data
* 20 sites have no digitalised data available for download (Geraldton, Bunbury ...)

We have only processed data for 30 sites out of the 50.

The list of sites is available by downloading a kml file (google earth) provided by DoT after registration.

This kml file is the point of truth to download the most up to date version of the waverider dataset from DoT WA. 
The AODN has created a python module to process this kml file regularly (set up with a cron job), and parses it to 
retrieve the needed information:
* https://github.com/aodn/data-services/tree/master/AODN/AODN-WAVE-DM

### b. KML description and data files
For each site, a link to download the matching data is provided in the kml file. In some case, no data is available 
since it hasn't been digitalised yet by the data provider. This link is a zip file containing the whole wave archive 
data for a specific site. 

Another link to a zip file containing basic metadata of this site is also available. The metadata file is always 
available even though no data was digitalised.

Follows is a link to a zip file example for the JUR40 site:
* https://s3-ap-southeast-2.amazonaws.com/transport.wa/WAVERIDER_DEPLOYMENTS/WaveRider_Yearly_Processed/JUR40_YEARLY_PROCESSED.zip 

This zip file contains yearly *.xls or *.xlsx files of the waverider data with limited information of the variable 
definition, the local time zone... This is the easiest case of data files to handle as there is a clear "physical"
separation between variables/columns.

Unfortunately, the data also exists for some sites as text files, with a file extension based on the number of the site
name. For example the following zip file
https://s3-ap-southeast-2.amazonaws.com/transport.wa/WAVERIDER_DEPLOYMENTS/WaveRider_Yearly_Processed/DAW22_YEARLY_PROCESSED.zip
contains  __*.022__ files. ```22``` being the number of the site code ```DAW22```.

Those files are text files with fix width columns, which is more prone to be wrongly parsed as there is no solid way to
separate columns/variables such as in csv files.. The ```read_fwf``` class from the python Pandas module was used in 
order to parse those files properly.

Many issues were found in trying to automate a solid system to harvest correctly the data. Some of the issues we came 
across with were:
* 2 column values not having any space between them, such as
```12.3012.15``` which is obviously wrong. 
* string and numbers mixed up in the same column
* wrong seconds values (3 digits instead of 2)

The lack of consistency of the different file formats made the parsing challenging, and tedious checking has helped to 
bring confidence in harvesting the data properly. 

More information (water depth, location and instrument model) about the site/deployments can be found by downloading a 
zip file containing one metadata file per deployments from the following link:
* https://s3-ap-southeast-2.amazonaws.com/transport.wa/WAVERIDER_DEPLOYMENTS/DeploymentMetadata/JUR40_Metadata.zip

### c) Data ingest and update
This python module downloads the waverider kml file as often as what is setup in the AODN cron job environment. If a 
site has a more up to date version of its data available, the downloaded zip file md5 checksum will be different from 
previously processed zip/data. 

Based on this difference, if required, the data will be downloaded, reprocessed and transformed into Climate and 
Forecast compliant NetCDF files. 

The NetCDF files are then pushed to the AODN pipeline infrastructure in order to be ingested in its database. The 
physical NetCDF file are also available on the AODN THREDDS server.

#### Using the Script
```bash
usage: wa_waverider_process.py [-h] [-o OUTPUT_PATH]

Creates FV01 NetCDF wave files from full waverider dataset. Prints
out the path of the new locally generated FV01 file.

optional arguments:
  -h, --help            show this help message and exit
  -o OUTPUT_PATH, --output-path OUTPUT_PATH
                        output directory of FV01 netcdf file. (Optional)

```


## Contact Support
for support contact:
Email: laurent.besnard@utas.edu.au
