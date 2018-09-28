Queensland Government Wave dataset (delay-mode)
=============

This script aims to convert wave data publicly available from the Queensland Government API into NetCDF files by using
the CKAN API to retrieve the data in JSON format.

The different sites are:
 
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
    
More information about the dataset at 
https://www.qld.gov.au/environment/coasts-waterways/beach/waves-sites


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
database file under `````$WIP_DIR/AODN/WAVE-QLD-DM````` (defined in __lib/common.py__). If the whole dataset
needs to be redownloaded, the `````$WIP_DIR/AODN/WAVE-QLD-DM````` folder can simply be deleted.


## Contact Support
for support contact:
Email: laurent.besnard@utas.edu.au
