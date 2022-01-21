# Installation of the ardc_nrt module
```bash
conda env create --file=environment.yml
conda activate ardc_nrt
```

# Usage as a script 
## Sofar
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

Create in ```/tmp/SOFAR``` a ```secrets.json``` file such as:

```json
{
    "UWA": "token_value",
    "VIC": "token_value"
}
```

```bash
export ARDC_SOFAR_SECRET_FILE_PATH="/tmp/SOFAR/secrets.json"
./ardc_sofar_nrt.py -o /tmp/sofar
```


## OMC 
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
Create in ```/tmp/OMC``` a ```secrets.json``` file such as:

```json
{
    "secrets": {
        "client_id": "value",
        "client_secret": "value"
    }
}
```

```bash
export ARDC_OMC_SECRET_FILE_PATH="/tmp/OMC/secrets.json"
ardc_sofar_nrt.py -o /tmp/omc
```


# Usage as a module
## OMC Examples

Example to find a list of source_id and their respective metadata

```python
import os 
os.environ["ARDC_OMC_SECRET_FILE_PATH"] = "/tmp/OMC/secrets.json"

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



## Sofar examples

```python
import os
os.environ["ARDC_SOFAR_SECRET_FILE_PATH"] = "/tmp/SOFAR/secrets.json"


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
