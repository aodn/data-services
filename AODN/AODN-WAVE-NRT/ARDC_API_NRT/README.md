<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Installation of the ardc_nrt python module](#installation-of-the-ardc_nrt-python-module)
- [BOM_WFS  <a name="bom_wfs"></a>](#bom_wfs--a-namebom_wfsa)
  - [Configuration](#configuration)
    - [Generic NetCDF template (template_omc.json)](#generic-netcdf-template-template_omcjson)
    - [Buoys/Spotters Metadata (sources_id_metadata.json)](#buoysspotters-metadata-sources_id_metadatajson)
    - [BOM - AODN variable mapping](#bom---aodn-variable-mapping)
    - [NetCDF filenaming](#netcdf-filenaming)
  - [Running the script](#running-the-script)
    - [Usage as a module](#usage-as-a-module)
    - [running as a script/cronjob](#running-as-a-scriptcronjob)
- [OMC API](#omc-api)
  - [Configuration](#configuration-1)
    - [Token, Authentication (secrets.json)](#token-authentication-secretsjson)
    - [Generic NetCDF template (template_omc.json)](#generic-netcdf-template-template_omcjson-1)
    - [Buoys/Spotters Metadata (sources_id_metadata.json)](#buoysspotters-metadata-sources_id_metadatajson-1)
    - [OMC - AODN variable mapping](#omc---aodn-variable-mapping)
    - [NetCDF filenaming](#netcdf-filenaming-1)
  - [Running the script](#running-the-script-1)
    - [Usage as a module](#usage-as-a-module-1)
      - [initialisation](#initialisation)
      - [devices information](#devices-information)
      - [get sources configuration](#get-sources-configuration)
    - [running as a script/cronjob](#running-as-a-scriptcronjob-1)
- [Sofar API](#sofar-api)
  - [Configuration](#configuration-2)
    - [Token, Authentication (secrets.json)](#token-authentication-secretsjson-1)
    - [Generic NetCDF template (template_[institution (lower case)].json)](#generic-netcdf-template-template_institution-lower-casejson)
    - [Buoys/Spotters Metadata (sources_id_metadata.json)](#buoysspotters-metadata-sources_id_metadatajson-2)
    - [SOFAR - AODN variable mapping](#sofar---aodn-variable-mapping)
    - [NetCDF filenaming](#netcdf-filenaming-2)
  - [Running the script](#running-the-script-2)
    - [Usage as a module](#usage-as-a-module-2)
      - [get sources configuration](#get-sources-configuration-1)
    - [running as a script/cronjob](#running-as-a-scriptcronjob-2)
- [Modifying pickle file](#modifying-pickle-file)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

ARDC WAVE API data download

TODO: Get an abstract of the project


# Installation of the ardc_nrt python module
```bash
conda env create --file=environment.yml
conda activate ardc_nrt
```

# BOM_WFS  <a name="bom_wfs"></a>

## Configuration
### Generic NetCDF template (template_omc.json)

The link to the generic NetCDF template file is 
* [template_bom.json](ardc_nrt/config/bom/template_bom.json)

More templates could be created and should be named ```template_[institution_code].json``` with the same institution_code
available in the ```sources_id_metadata.json``` for each source_id. See below for more explaination.

This template contains all the global attributes and variables common to all the source_id's

For any specific attributes and variables, please see the next below regarding ```sources_id_metadata.json```


### Buoys/Spotters Metadata (sources_id_metadata.json)

```sources_id_metadata.json``` example:

```json
{
  "52121": {
    "_variables": {
      "TIME": {
        "long_name": "this is a test"
      }
    },
    "id": "52121",
    "site_code": "unknown",
    "site_name": "unknown",
    "institution_code": "bom",
    "deployment_start_date": "2022-01-01T00:00:00.000000Z",
    "latitude_nominal": "-12.68",
    "longitude_nominal": "141.68"
  }
}
```

The link to the production config file is [sources_id_metadata.json](ardc_nrt/config/bom/sources_id_metadata.json)

This file contains all the different ```source_id``` to query from the BOM WFS. In this example:
* "52121"

For every set of source_id, all following values above will be set in the final NetCDF file. 
More information on the templating can be found at [aodntools ncwriter](https://github.com/aodn/python-aodntools/tree/master/aodntools/ncwriter)


!! TIP:

All the source_id values can be found by running the ardc_nrt code as a module if more 
source_id need to be added in the above ```sources_id_metadata.json```:
check the section below -> __Usage as a module__

### BOM - AODN variable mapping
The AODN variables are correctly defined in NetCDF templates described above.

However, the mapping between an BOM variable and an AODN variable is made possible in
[variables_lookup.json](ardc_nrt/config/bom/variables_lookup.json)

If a variable retrieved from the WFS is not found in this ```variables_lookup.json```
file, the code will currently write a warning (this maybe should be changed) and create a NetCDF without it

### NetCDF filenaming

The NetCDF filename is created from both information found in ```sources_id_metadata.json``` and
the data.

The filename logic is currently:
```[institution_name]_W_[site_code]_[start_time_UTC]_FV00_END-{end_time_UTC].nc```

see function ```convert_wave_data_to_netcdf``` in [netcdf.py](ardc_nrt/lib/common/netcdf.py)


## Running the script

### Usage as a module

Example to find a list of source_id and their respective metadata

```python
from ardc_nrt.lib.bom.wfs import bomWFS

bom = bomWFS()

bom.get_sources_id_metadata()
Out[4]:
     source_id    lat     lon
0        52121 -12.68  141.68
3        55014 -35.73  150.32
4        55018 -30.37  153.27
...


bom.get_source_id_metadata(52121)
Out[7]:
   source_id    lat     lon
0      52121 -12.68  141.68


bom.get_source_id_data(52121)
Out[8]:
     source_id                 timestamp    lat     lon  ...  sprd_dom_wav  smpl_int_f  smpl_int_w  rcrd_dur
0        52121 2022-03-07 02:30:00+00:00 -12.68  141.68  ...          25.0         0.8         NaN    1597.0
1        52121 2022-03-07 02:00:00+00:00 -12.68  141.68  ...          27.0         0.8         NaN    1597.0
...
```



### running as a script/cronjob


```bash
usage: ardc_bom_nrt.py [-h] -o OUTPUT_PATH [-p INCOMING_PATH]

Creates NetCDF files from an ARDC WAVE API. Prints out the path of the new locally generated NetCDF file.

optional arguments:
  -h, --help            show this help message and exit
  -o OUTPUT_PATH, --output-path OUTPUT_PATH
                        output directory of FV00 netcdf file
  -p INCOMING_PATH, --push-to-incoming INCOMING_PATH
                        incoming directory for files to be ingested by AODN pipeline (Optional)
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
```[institution_name]_W_[site_code]_[start_month_time_UTC]_monthly_FV00nc```

see function ```convert_wave_data_to_netcdf``` in [netcdf.py](ardc_nrt/lib/common/netcdf.py)


## Running the script


### Usage as a module

Example to find a list of source_id and their respective metadata

#### initialisation
```python
import os
from ardc_nrt.lib.omc.api import omcApi

# set secrets
os.environ["ARDC_OMC_SECRET_FILE_PATH"] = "/[PLEASE EDIT ME]/secrets.json"

```

#### devices information
```python
# Get devices info
omcApi().get_sources_info()
Out[1]:
0  b7b3ded0-6758-4006-904f-db45f8cc012e         1       B10       Beacon 10  ...                  Beacon 10 Tide                  Beacon 10 AWAC                  Beacon 10 Wind                               NaN
1  79cfe155-748c-4daa-a152-13bf7c0290d2         0       B15       Beacon 15  ...                             NaN                         primary                             NaN                               NaN
2  9d129524-9f82-426f-ad87-112f377497b5         0       B16       Beacon 16  ...                             NaN                         primary                         primary                           primary
3  55e5864e-9a29-4fd8-838e-beeb1ef611b7         3        B3        Beacon 3  ...                   Beacon 3 Tide                   Beacon 3 AWAC                             NaN                               NaN
4  1f0c2644-7c1e-41b0-8d94-850bf0a85695         3  Beacon 2        Beacon 2  ...                             NaN                             NaN                             NaN                               NaN
5  8c5cdc02-e239-4419-90b8-afa504389f9d         0        GP  Gannet Passage  ...                             NaN             Gannet Passage Wave                             NaN                               NaN

[6 rows x 14 columns]

# Get source_id latest date available
source_id = "b7b3ded0-6758-4006-904f-db45f8cc012e"
omcApi(source_id).get_source_id_wave_latest_date()
Out[1]:
Timestamp('2022-03-04 04:58:00+0000', tz='UTC')

# Get source info
omcApi(source_id).get_source_info()
Out[1]:
                                     id  revision name  long_name  ... default_providers.tide_observed default_providers.wave_observed default_providers.wind_observed  default_providers.meteo_observed
0  b7b3ded0-6758-4006-904f-db45f8cc012e         1  B10  Beacon 10  ...                  Beacon 10 Tide                  Beacon 10 AWAC                  Beacon 10 Wind                               NaN

[1 rows x 14 columns]
```


#### get sources configuration
```python
from ardc_nrt.lib.common.lookup import lookup
lookup('config/omc').get_sources_id_metadata()

Out[1]:
                            b7b3ded0-6758-4006-904f-db45f8cc012e  79cfe155-748c-4daa-a152-13bf7c0290d2  ...  1f0c2644-7c1e-41b0-8d94-850bf0a85695  8c5cdc02-e239-4419-90b8-afa504389f9d
_variables             {'TIME': {'long_name': 'this is a test'}}                                   NaN  ...                                   NaN                                   NaN
id                          b7b3ded0-6758-4006-904f-db45f8cc012e  79cfe155-748c-4daa-a152-13bf7c0290d2  ...  1f0c2644-7c1e-41b0-8d94-850bf0a85695  8c5cdc02-e239-4419-90b8-afa504389f9d
site_code                                                    B10                                   B15  ...                                   NaN                                   NaN
site_name                                              Beacon 10                             Beacon 15  ...                                   NaN                                   NaN
institution_code                                             omc                                   omc  ...                                   omc                                   omc
deployment_start_date                2021-11-18T07:12:36.345066Z           2021-11-18T07:12:36.345066Z  ...                                   NaN                                   NaN
latitude_nominal                                                                                        ...                                   NaN                                   NaN
longitude_nominal 
```

```python
lookup('config/omc').get_matching_aodn_variable('hs')
Out[1]: 'WSSH'
```

```python
lookup('config/sofar').get_source_id_deployment_start_date("SPOT-0278")
Out[1]: Timestamp('2021-09-01 00:00:00+0000', tz='UTC')
```

```python
lookup('config/sofar').get_source_id_metadata("b7b3ded0-6758-4006-904f-db45f8cc012e")
Out[1]:
_variables               {'TIME': {'long_name': 'this is a test'}}
id                            b7b3ded0-6758-4006-904f-db45f8cc012e
site_code                                                      B10
site_name                                                Beacon 10
institution_code                                               omc
deployment_start_date                  2021-11-18T07:12:36.345066Z
latitude_nominal
longitude_nominal
Name: b7b3ded0-6758-4006-904f-db45f8cc012e, dtype: object
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
```[institution_name]_W_[site_code]_[start_month_time_UTC]_monthly_FV00.nc```

see function ```convert_wave_data_to_netcdf``` in [netcdf.py](ardc_nrt/lib/common/netcdf.py)



## Running the script


### Usage as a module

Example to find a list of source_id and their respective metadata


```python
import os
os.environ["ARDC_SOFAR_SECRET_FILE_PATH"] = "/[PLEASE EDIT ME]/secrets.json"

from ardc_nrt.lib.sofar.api import sofarApi
sofarApi().lookup_get_tokens()
Out[1]:
{'UWA': 'value',
 'VIC': 'value'}


sofarApi().get_devices_info(sofarApi().lookup_get_tokens()['UWA'])
Out[1]:
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


sofarApi().get_source_id_latest_data('SPOT-0169')
Out[1]:
   significantWaveHeight  peakPeriod  meanPeriod  peakDirection  peakDirectionalSpread  meanDirection  meanDirectionalSpread                 timestamp  latitude  longitude
0                  0.444       8.533       5.838         81.276                 39.654         77.963                 45.089 2022-03-04 05:37:18+00:00 -35.07945  117.97868


```


#### get sources configuration
```python
from ardc_nrt.lib.common.lookup import lookup
lookup('config/sofar').get_sources_id_metadata()

Out[1]:
spotter_id                            SPOT-0278                 SPOT-0297                 SPOT-0316  ...                 SPOT-1266                 SPOT-1294                 SPOT-1292
site_name                              Mt Eliza                                                      ...                  Hillarys                   Dampier             Goodrich Bank
site_code                             SPOT-0278                 SPOT-0297                 SPOT-0316  ...                 SPOT-1266                 SPOT-1294                 SPOT-1292
deployment_id                                 1                         1                         1  ...                         1                         1                         1
deployment_start_date  2021-09-01T00:00:00.000Z  2021-01-01T00:00:00.000Z  2021-01-01T00:00:00.000Z  ...  2020-01-01T00:00:00.000Z  2020-01-01T00:00:00.000Z  2020-01-01T00:00:00.000Z
deployment_end_date                                                                                  ...
latitude_nominal                         -38.32                    -38.32                    -38.32  ...                    -38.32                    -38.32                    -38.32
longitude_nominal                        141.65                    141.65                    141.65  ...                    141.65                    141.65                    141.65
institution_code                            VIC                       VIC                       VIC  ...                       UWA                       UWA                       UWA
```

```python
lookup('config/sofar').get_matching_aodn_variable('meanPeriod')
Out[1]: 'WPFM'
```

```python
lookup('config/sofar').get_source_id_deployment_start_date("SPOT-0278")
Out[1]: Timestamp('2021-09-01 00:00:00+0000', tz='UTC')
```

```python
lookup('config/sofar').get_source_id_metadata("SPOT-0278")
Out[1]:
spotter_id                              SPOT-0278
site_name                                Mt Eliza
site_code                               SPOT-0278
deployment_id                                   1
deployment_start_date    2021-09-01T00:00:00.000Z
deployment_end_date
latitude_nominal                           -38.32
longitude_nominal                          141.65
institution_code                              VIC
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

For reprocessing purposes, it can be useful to modify the pickle file, which stores information about the
latest date successfully processed for each source_id

Below are a few examples on how to achieve this:
```python
import os
from ardc_nrt.lib.omc.api import omcApi
output_path = '/output_dir/omc' # location of the pickle file
from ardc_nrt.lib.common.pickle_db import ardcPickle

# Returns information regarding the latest downloaded source_id's
ardcPickle(output_path).load()
Out[1]: {'79cfe155-748c-4daa-a152-13bf7c0290d2': {
    'latest_downloaded_date': Timestamp('2022-03-01 07:45:00+0000', tz='UTC')
}
}

# Deletes source_id from pickle file (for full reprocessing for example)
ardcPickle(output_path).delete_source_id('79cfe155-748c-4daa-a152-13bf7c0290d2')       

# Modify or create latest_downloaded_date of a source_id
import pandas
newTimestampVal = pandas.Timestamp(year=2022,month=3,day=1,hour=0,minute=0,second=0, tz='UTC')
ardcPickle(output_path).mod_source_id_latest_downloaded_date('new_source_id0', newTimestampVal)

# confirm new timestamp value
ardcPickle(output_path).load()
Out[1]:
{'79cfe155-748c-4daa-a152-13bf7c0290d2':
    {'latest_downloaded_date': Timestamp('2022-03-01 07:45:00+0000', tz='UTC')},
 'new_source_id0': 
    {'latest_downloaded_date': Timestamp('2022-03-01 00:00:00+0000', tz='UTC')}
}
```