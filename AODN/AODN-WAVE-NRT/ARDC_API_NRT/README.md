ARDC WAVE API data download

TODO: Get an abstract of the project


# Installation of the ardc_nrt python module
```bash
conda env create --file=environment.yml
conda activate ardc_nrt
```

# OMC API

## Configuration

### Token, Authentication (secrets.json)

On the running machine, create in ```$WIP_DIR/ARDC_API_NRT/OMC``` a ```secrets.json``` file containing the correct values
in order to be granted access to the OMC API:

```json
{
    "secrets": {
        "client_id": "value",
        "client_secret": "value"
    }
}
```
and run in bash in the correct environment
```bash
export ARDC_OMC_SECRET_FILE_PATH="/[PLEASE EDIT ME]/secrets.json"
```

This should be chef-managed

### Generic NetCDF template (template_omc.json)

The link to the generic NetCDF template file is 
* [template_omc.json](ardc_nrt/config/omc/template_omc.json)

This template contains all the global attributes and variables common to all the source_id's

For any specific attributes and variables, please see the next below regarding ```sources_id_metadata.json```


### Buoys/Spotters Metadata (sources_id_metadata.json)

```sources_id_metadata.json``` example:

```json
{
  "b7b3ded0-6758-4006-904f-db45f8cc012e": {
    "_variables": {
      "TIME": {
        "long_name": "this is a test"
      }
    },
    "id": "b7b3ded0-6758-4006-904f-db45f8cc012e",
    "site_code": "B10",
    "site_name": "Beacon 10",
    "institution_code": "omc",
    "deployment_start_date": "2021-11-18T07:12:36.345066Z",
    "latitude_nominal": "",
    "longitude_nominal": ""
  },
    "79cfe155-748c-4daa-a152-13bf7c0290d2": {
    "id": "79cfe155-748c-4daa-a152-13bf7c0290d2",
    "site_code": "B15",
    "site_name": "Beacon 15",
    "institution_code": "omc",
    "deployment_start_date": "2021-11-18T07:12:36.345066Z",
    "latitude_nominal": "",
    "longitude_nominal": ""
  }
}
```

The link to the production config file is [sources_id_metadata.json](ardc_nrt/config/omc/sources_id_metadata.json)

This file contains all the different ```source_id``` to query from the OMC API. In this example:
* b7b3ded0-6758-4006-904f-db45f8cc012e
* 79cfe155-748c-4daa-a152-13bf7c0290d2

For every set of source_id, all following values above will be set in the final NetCDF file. 
More information on the templating can be found at [aodntools ncwriter](https://github.com/aodn/python-aodntools/tree/master/aodntools/ncwriter)


!! TIP:

All the source_id values can be found by running the ardc_nrt code as a module if more 
source_id need to be added in the above ```sources_id_metadata.json```:
check the section below -> __Usage as a module__

### OMC - AODN variable mapping
The AODN variables are correctly defined in NetCDF templates described above.

However, the mapping between an OMC variable and an AODN variable is made possible in
[variables_lookup.json](ardc_nrt/config/omc/variables_lookup.json)

If a variable retrieved from the REST API is not found in this ```variables_lookup.json```
file, the code will currently write a warning (this maybe should be changed) and create a NetCDF without it

### NetCDF filenaming

The NetCDF filename is created from both information found in ```sources_id_metadata.json``` and
the data.

The filename logic is currently 
```[institution_name]_W_[site_code]_[start_time_UTC]_FV00.nc```

see function ```convert_wave_data_to_netcdf``` in [netcdf.py](ardc_nrt/lib/common/netcdf.py)


## Running the script


### Usage as a module

Example to find a list of source_id and their respective metadata

```python
import os 
os.environ["ARDC_OMC_SECRET_FILE_PATH"] = "/[PLEASE EDIT ME]/secrets.json"

import ardc.lib.omc.config
from ardc.lib.omc.api import api_get_access_token
 
api_get_access_token()
 
from ardc.lib.omc.api import api_get_sources_info
df = api_get_sources_info()
 
df

                                     id  revision      name       long_name    description  ...                 created_time_utc default_providers.tide_observed  default_providers.wave_observed  default_providers.wind_observed default_providers.meteo_observed
0  b7b3ded0-6758-4006-904f-db45f8cc012e         1       B10       Beacon 10                 ... 2021-11-18 07:12:36.345066+00:00                  Beacon 10 Tide                   Beacon 10 AWAC                   Beacon 10 Wind                              NaN
1  79cfe155-748c-4daa-a152-13bf7c0290d2         0       B15       Beacon 15                 ... 2021-11-18 02:21:31.873079+00:00                             NaN                          primary                              NaN                              NaN
2  9d129524-9f82-426f-ad87-112f377497b5         0       B16       Beacon 16                 ... 2021-11-18 02:21:28.048669+00:00                             NaN                          primary                          primary                          primary
3  55e5864e-9a29-4fd8-838e-beeb1ef611b7         3        B3        Beacon 3                 ... 2021-11-18 07:11:49.418060+00:00                   Beacon 3 Tide                    Beacon 3 AWAC                              NaN                              NaN
4  1f0c2644-7c1e-41b0-8d94-850bf0a85695         3  Beacon 2        Beacon 2  Beacon 2 Wave  ... 2022-01-25 14:37:43.690484+00:00                             NaN                              NaN                              NaN                              NaN
5  8c5cdc02-e239-4419-90b8-afa504389f9d         0        GP  Gannet Passage                 ... 2022-01-12 00:18:00.936159+00:00                             NaN              Gannet Passage Wave                              NaN                              NaN
```

### running as a script/cronjob


```bash
usage: ardc_omc_nrt.py [-h] -o OUTPUT_PATH [-p INCOMING_PATH]

Creates NetCDF files from an ARDC WAVE API. Prints out the path of the new locally generated NetCDF file.

optional arguments:
  -h, --help            show this help message and exit
  -o OUTPUT_PATH, --output-path OUTPUT_PATH
                        output directory of FV00 netcdf file
  -p INCOMING_PATH, --push-to-incoming INCOMING_PATH
                        incoming directory for files to be ingested by AODN pipeline (Optional)
```


```bash
export ARDC_OMC_SECRET_FILE_PATH="/[PLEASE EDIT ME]/OMC/secrets.json"
./ardc_omc_nrt.py -o [PLEASE EDIT ME]/output
```

The script will:
* query the OMC API to find new data to download
* check in the output directory for a [pickle](https://docs.python.org/3/library/pickle.html) file to see which data has already been downloaded
* download new monthly data
* create monthly NetCDF
* save in the pickle file the latest date of downloaded data for each source_id
* push the NetCDF to an $INCOMING_DIR for ingestion

# Sofar API


## Configuration

### Token, Authentication (secrets.json)

On the running machine, create in ```$WIP_DIR/ARDC_API_NRT/SOFAR``` a ```secrets.json``` file containing the correct values
in order to be granted access to the various institutions hosted by the SOFAR API:

```json
{
    "UWA": "token_value",
    "VIC": "token_value"
}
```
and run in bash in the correct environment
```bash
export ARDC_SOFAR_SECRET_FILE_PATH="/[PLEASE EDIT ME]/secrets.json"
```

This should be chef-managed


### Generic NetCDF template (template_[institution (lower case)].json)

The link to a generic NetCDF template file is 
* [template_vic.json](ardc_nrt/config/sofar/template_vic.json)

This template contains all the global attributes and variables common to all the source_id's for an institution only

Note that there are so far 2 institutions (VIC, UWA). If a new institution needs to be added,
it should be created first in the ```secrets.json```, as well as a new ```template_[institution (lower case)].json``` file

For any specific attributes and variables, please see the next below regarding ```sources_id_metadata.json```


### Buoys/Spotters Metadata (sources_id_metadata.json)

```sources_id_metadata.json``` example:

```json
{
  "SPOT-0278": {
    "spotter_id": "SPOT-0278",
    "site_name": "Mt Eliza",
    "site_code": "SPOT-0278",
    "deployment_id": 1,
    "deployment_start_date": "2020-01-01T00:00:00.000Z",
    "deployment_end_date": "",
    "latitude_nominal": -38.32,
    "longitude_nominal": 141.65,
    "institution_code": "VIC"
  },
  "SPOT-0297": {
    "spotter_id": "SPOT-0297",
    "site_name": "",
    "site_code": "SPOT-0297",
    "deployment_id": 1,
    "deployment_start_date": "2020-01-01T00:00:00.000Z",
    "deployment_end_date": "",
    "latitude_nominal": -38.32,
    "longitude_nominal": 141.65,
    "institution_code": "VIC"
  }
}
```

The link to the production config file is [sources_id_metadata.json](ardc_nrt/config/sofar/sources_id_metadata.json)

This file contains all the different ```source_id``` to query from the SOFAR API. In this example:
* SPOT-0278
* SPOT-0297

For every set of source_id, all following values above will be set in the final NetCDF file. 
More information on the templating can be found at [aodntools ncwriter](https://github.com/aodn/python-aodntools/tree/master/aodntools/ncwriter)


!! TIP:

All the source_id values can be found by running the ardc_nrt code as a module if more 
source_id need to be added in the above ```sources_id_metadata.json```:
check the section below -> __Usage as a module__

### SOFAR - AODN variable mapping
The AODN variables are correctly defined in NetCDF templates described above.

However, the mapping between a SOFAR variable and an AODN variable is made possible in
[variables_lookup.json](ardc_nrt/config/sofar/variables_lookup.json)

If a variable retrieved from the REST API is not found in this ```variables_lookup.json```
file, the code will currently write a warning (this maybe should be changed) and create a NetCDF without it

### NetCDF filenaming

The NetCDF filename is created from both information found in ```sources_id_metadata.json``` and
the data.

The filename logic is currently 
```[institution_name]_W_[site_code]_[start_time_UTC]_FV00.nc```

see function ```convert_wave_data_to_netcdf``` in [netcdf.py](ardc_nrt/lib/common/netcdf.py)



## Running the script


### Usage as a module

Example to find a list of source_id and their respective metadata


```python
import os
os.environ["ARDC_SOFAR_SECRET_FILE_PATH"] = "/[PLEASE EDIT ME]/secrets.json"

from ardc_nrt.lib.sofar import config
from ardc_nrt.lib.sofar.api import api_get_devices_info, lookup_get_tokens

api_get_devices_info(lookup_get_tokens()['UWA'])

                                      name  spotterId
0            King George Sound (SPOT-0169)  SPOT-0169
1   Drifting #1- Bremer Canyon (SPOT-0170)  SPOT-0170
2              TwoRocksDrift01_(SPOT-0162)  SPOT-0162
3                Sofar Drifter (SPOT-0172)  SPOT-0172
4                  Torbay East (SPOT-0171)  SPOT-0171
5              TwoRocksDrift03_(SPOT-0168)  SPOT-0168
6                     Hillarys (SPOT-0093)  SPOT-0093
7            Goodrich Bank OLD (SPOT-0551)  SPOT-0551
8                   Tantabiddi (SPOT-0558)  SPOT-0558
9                  Torbay East (SPOT-0559)  SPOT-0559
10                     Dampier (SPOT-0561)  SPOT-0561
11                 Torbay West (SPOT-0757)  SPOT-0757
12                                          SPOT-1040
13             TwoRocksDrift02_(SPOT-1266)  SPOT-1266
14                     Dampier (SPOT-1294)  SPOT-1294
15               Goodrich Bank (SPOT-1292)  SPOT-1292
16                                          SPOT-1668
17                                          SPOT-1667
18                                          SPOT-1669
```


### running as a script/cronjob


```bash
usage: ardc_sofar_nrt.py [-h] -o OUTPUT_PATH [-p INCOMING_PATH]

Creates NetCDF files from an ARDC WAVE API. Prints out the path of the new locally generated NetCDF file.

optional arguments:
  -h, --help            show this help message and exit
  -o OUTPUT_PATH, --output-path OUTPUT_PATH
                        output directory of FV00 netcdf file
  -p INCOMING_PATH, --push-to-incoming INCOMING_PATH
                        incoming directory for files to be ingested by AODN pipeline (Optional)
```


```bash
export ARDC_SOFAR_SECRET_FILE_PATH="/[PLEASE EDIT ME]/SOFAR/secrets.json"
./ardc_sofar_nrt.py -o [PLEASE EDIT ME]/output
```

The script will:
* query the SOFAR API to find new data to download
* check in the output directory for a [pickle](https://docs.python.org/3/library/pickle.html) file to see which data has already been downloaded
* download new monthly data
* create monthly NetCDF
* save in the pickle file the latest date of downloaded data for each source_id
* push the NetCDF to an $INCOMING_DIR for ingestion


# Modifying pickle file