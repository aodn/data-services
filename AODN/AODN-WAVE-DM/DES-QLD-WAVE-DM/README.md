Queensland Government Wave dataset (delayed-mode)
=============
### a. Introduction
The Department of Environment and Science of Queensland (DES-QLD) has deployed Waverider buoys along
its coast since 1974. A total of 50 sites exists:
 
__South East Queensland__

    Tweed Heads
    Palm Beach
    Gold Coast
    Brisbane
    North Moreton Bay
    Caloundra
    Mooloolaba

__Mackay and Fitzroy Central__

    Bundaberg
    Gladstone
    Emu Park
    Hay Point
    Mackay
    Mackay Inner

__North Queensland__

    Abbot Point
    Townsville

__Far North Queensland__

    Cairns
    Albatross Bay (Weipa)
    
### b. data availability
The delayed mode data and metadata is accessible by querying the CKAN API developed by the DES-QLD. The api is called 
from the developed python module (https://github.com/aodn/data-services/tree/master/AODN/AODN-WAVE-DM/DES-QLD-WAVE-DM) 
which parses the output of the API as a JSON output.

More information on how to query the API can be found at 
https://data.qld.gov.au/api/1/util/snippet/api_info.html?resource_id=&datastore_root_url=

Each deployment is downloaded as a single file and transformed into a Climate and Forcast compliant NetCDF file.

### c. data quality
There are a certain amount of issues with the data quality:
* empty time values
* many different fillvalue values
* variable values staying at the same value for many month
* ... 

### d. Data ingest and update
This python module downloads the waverider kml file as often as what is setup in the AODN cron job environment. It is 
possible to query the CKAN API to know if a more up to date version of the data is available for a specific 
deployment/package. In this case, the data will be re-downloaded and transformed into Climate and Forecast compliant 
NetCDF files. 

The NetCDF files are then pushed to the AODN pipeline infrastructure in order to be ingested in its database. The 
physical NetCDF file are also available on the AODN THREDDS server.
## Using the Script
```bash
usage: get_qld_wave_dm_data.py [-h] [-o OUTPUT_PATH]

Creates FV01 NetCDF files (WAVE) from full dataset. Prints
out the path of the new locally generated FV01 file (in a temporary folder by default, or can be 
set to a pipeline incoming directory. Correct permissions are already set up in the script).

optional arguments:
  -h, --help            show this help message and exit

  -o OUTPUT_PATH, --output-path OUTPUT_PATH
                        output directory of FV01 netcdf file. (Optional)

```

This script can be run as a cron job with as a __projectofficer__ user in order to create a pickle
database file under `````$WIP_DIR/AODN/DES-QLD-WAVE-DM````` (defined in __lib/common.py__). If the whole dataset
needs to be redownloaded, the `````$WIP_DIR/AODN/DES-QLD-WAVE-DM````` folder can simply be deleted.


## Contact Support
for support contact:
Email: laurent.besnard@utas.edu.au
