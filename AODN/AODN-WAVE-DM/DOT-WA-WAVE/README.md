Dept. Of Transport of Western Australia - Wave dataset
=============

## AWAC instrument

Converts wave, tide, status, current and temperature data from the Dept. of Transport WA into NetCDF files.
This dataset was collected using a AWAC Nortek 1mhz instrument.

The data is downloaded by parsing information from the following KML file:
https://s3-ap-southeast-2.amazonaws.com/transport.wa/DOT_OCEANOGRAPHIC_SERVICES/AWAC_V2/AWAC.kml

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

## Waverider instrument: dataset description

Waverider buoys have been deployed along the coast of Western Australia by the Department of Transport since 1974. A 
total of 50 sites exists:
* 43 sites are historic ones with no on-going data
* 7 sites are current ones with on-going data
* 20 sites have no digitalised data available for download (Geraldton, Bunbury ...)

We have only processed data for 30 sites out of the 50.

The list of sites is available by downloading the following kml file (google earth):
https://s3-ap-southeast-2.amazonaws.com/transport.wa/WAVERIDER_DEPLOYMENTS/WaveStations.kml

This kml file is the point of truth to download the most up to date version of the waverider dataset. Our python script
downloads this kml file regularly (set up by a cron job), and parses it to retrieve the information needed. 

For each site, a link, if available, is provided in this kml to download the full wave dataset of a site as a zip file. 
Another link to a zip file containing some metadata of this site is also available for download even though we fall in 
the case that no digitalised data was provided.

Each zip file



 



Converts wave data from the waverider instruments. Only the digital data is being processed from the following KML file:

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
