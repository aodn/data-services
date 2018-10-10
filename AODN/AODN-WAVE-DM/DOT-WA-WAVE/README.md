Dept. Of Transport - WA - AWAC Nortek Instrument
=============

This script aims to convert wave, tide, status, current and temperature data from the Dept. of Transport into NetCDF files.

This dataset was collected using a AWAC Nortek 1mhz instrument.

The data is retrieved within this script using
https://s3-ap-southeast-2.amazonaws.com/transport.wa/DOT_OCEANOGRAPHIC_SERVICES/AWAC_V2/AWAC.kml

## Using the Script
```bash
usage: wa_awac_process.py [-h] -i DATASET_PATH [-o OUTPUT_PATH]

Creates FV01 NetCDF files (WAVE, TIDES...) from full WA_AWAC dataset. Prints
out the path of the new locally generated FV01 file.

optional arguments:
  -h, --help            show this help message and exit
  -o OUTPUT_PATH, --output-path OUTPUT_PATH
                        output directory of FV01 netcdf file. (Optional)

```

## Location of Original Dataset

The dataset was previously downloaded and archived to ```$ARCHIVE_DIR/AODN/Dept-Of-Transport_WA_WAVES```
However the most up to date dateset is found via the kml file (link above)

## Contact Support
for support contact:
Email: laurent.besnard@utas.edu.au
