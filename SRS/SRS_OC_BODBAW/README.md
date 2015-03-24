# BioOptical Database data processing

Series of script to run manually to process pigment, asborption and AC9-HS6 data files. The files are provided by Lesley Clementson. The files usually go through many passes before being good. The checker being this code ! If it fails, debuging is required. Templates provided aren't always followed, and new features can appear every now and then (strings instead of integers, many values for a same TIME,LON,LAT,DEPTH ...)

__This script has to be run manually and checked by a human because of the unlikelyhood of getting good files straight on.__

## Installation

### setup.sh
The __setup.sh__ file will create a working environment to start processing data from the BODBAW subfacility

Run as root
```bash
sudo ./setup.sh
```

This script :
 * initialises PERL
 * installs PERL dependencies
 * downloads and modifies the xls2csv PERL package
 * clones or pulls the imos user code library AODN git repository (used for the plotting). see https://github.com/aodn/imos-user-code-library/wiki/Using-the-IMOS-User-Code-Library-with-MATLAB


If the script fails for any reason, try to install things manually. Fairly self-explanatory

### config.txt
Modify config.txt to give the path of the pigment absorption and backscattering XLS or CSV files.

__WARNING__ : Output files will be in the same locations as the input ones


## Usage
Depending of the data to process, launch in Matlab either
```matlab
mainAbsorption % Process Absorption data. Convert XLS 2 CSV, and create a NetCDF files, plots and CSV files
```

```matlab
mainPigment % Process Pigment data
```

```matlab
mainAC9_HS6  % Process AC9-HS6 data
```

## Output
In each data folder there will be :

 * a CSV folder to put into $PUBLIC/SRS/SRS_BODBAW
 * a NetCDF folder to put into $OPENDAP/SRS/SRS_BODBAW
 * an explortedPlots folder to put into $PUBLIC/SRS/SRS_BODBAW (used by the content.ftl of geoserver)

The plots are extremely useful to quickly check if the data is good.

## Contact
laurent.besnard@utas.edu.au (creator of the script)

lesley.clementson@csiro.au  (Principal Investigator of the dataset)


