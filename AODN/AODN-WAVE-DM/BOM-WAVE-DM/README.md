Bureau Of Meteorology Waverider buoys Delayed Mode data collection
=============

This script aims to convert wave files in various format(csv, xls, xlsx) from the Bureau of Meteorology into NetCDF files.

The data was collected on two different stations:
* Cape Sorell (1998 -> 2017)
* Cape Du Couedic (2000 -> 2017)

More info can be found on the manual available in this folder:
BOM_WAVE_DM_RevAOceanSenseQualityManual.pdf

## Location of Original Dataset

The original files can be found on 10-nec-hob under:
 ```$ARCHIVE_DIR/AODN/BOM_WAVE_DM```

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
Example:
bom_wave_dm_process.py -i AODN/BOM_WAVE_DM -o /tmp

## Contact Support
for support contact:
Email: laurent.besnard@utas.edu.au
