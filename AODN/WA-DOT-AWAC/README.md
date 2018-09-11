Dept. Of Transport - WA - AWAC Nortek Instrument
=============

This script aims to convert wave, tide, status, current and temperature data from the Dept. of Transport into NetCDF files.

The dataset was collected using a AWAC Nortek 1mhz instrument.

## Using the Script
```bash
usage: wa_awac_process.py [-h] -i DATASET_PATH [-o OUTPUT_PATH]

Creates FV01 NetCDF files (WAVE, TIDES...) from full WA_AWAC dataset. Prints
out the path of the new locally generated FV01 file.

optional arguments:
  -h, --help            show this help message and exit
  -i DATASET_PATH, --wave-dataset-org-path DATASET_PATH
                        path to original wave dataset
  -o OUTPUT_PATH, --output-path OUTPUT_PATH
                        output directory of FV01 netcdf file. (Optional)

```

## Location of Original Dataset

The original files can be found on ```$ARCHIVE_DIR/AODN/Dept-Of-Transport_WA_WAVES```

## Contact Support
for support contact:
Email: laurent.besnard@utas.edu.au
