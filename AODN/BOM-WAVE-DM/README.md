Bureau Of Meteorology Wave Delayed Mode dataset
=============

This script aims to convert wave files in various format(csv, xls, xlsx) from the Bureau of Meteorology into NetCDF files.

The data was collected on two different stations:
* Cape Sorrel (1998 -> 2017)
* Cape Du Couedic (2000 -> 2017)

More info can be found on the manual available in this folder:
BOM_WAVE_DM_RevAOceanSenseQualityManual.pdf

## Using the Script
```bash
usage: bom_wave_dm_process.py [-h] -i DATASET_PATH [-o OUTPUT_PATH]

Creates FV01 NetCDF files from BOM WAVE Delayed Mode dataset. Prints out the
path of the new locally generated FV01 file.

optional arguments:
  -h, --help            show this help message and exit
  -i DATASET_PATH, --wave-dataset-org-path DATASET_PATH
                        path to original wave dataset
  -o OUTPUT_PATH, --output-path OUTPUT_PATH
                        output directory of FV01 netcdf file. (Optional)

```

## Location of Original Dataset

The original files can be found on ```$ARCHIVE_DIR/AODN/BOM_WAVE_DM```

## Contact Support
for support contact:
Email: laurent.besnard@utas.edu.au
