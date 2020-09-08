# BioOptical Database data processing

Python script creating CF compliant NetCDF files from XLXS/XLS spreadsheet of data containing absorption, AC9-HS6, piment, TSS data.

## Usage

```bash
./srs_oc_bodbaw_netcdf_creation.py -h
usage: srs_oc_bodbaw_netcdf_creation.py [-h] [-i INPUT_EXCEL_PATH]
                                        [-o [OUTPUT_FOLDER]]

optional arguments:
  -h, --help            show this help message and exit
  -i INPUT_EXCEL_PATH, --input-excel-path INPUT_EXCEL_PATH
                        path to excel file or directory
  -o [OUTPUT_FOLDER], --output-folder [OUTPUT_FOLDER]
                        output directory of generated files

```

The plots are extremely useful to quickly check if the data is good.

## Installation

1) clone github repo ```git clone https://github.com/aodn/data-services.git```
2) install conda and create a python conda environment from the root of the repo ```conda env create -f environment.yml```
3) activate the conda environment ```conda activate data_services_3.5```
4) run script

## Contact
laurent.besnard@utas.edu.au (creator of the script)

lesley.clementson@csiro.au  (Principal Investigator of the dataset)


