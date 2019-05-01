# Time Series aggregator

This script, developped originally by [Pete Jensen](https://github.com/petejan/imos-tools) collects data for selected variables for all instruments at a particular site and produces a single netCDF file with all the variables for all deployments.

The script now supports files without the variable(s) of interest.

## HOWTO run the script

You need first need to get the file addresses of all the files for a particular site. Then input those name to the aggregator script.

1. Retrieve the list of all FV01 required files from the AODN THREDDS server using the `catalog.py` code and send the output to a text file. This file will be the input of the next script. Go to the THREDDS catalog and select the correct path, e.g. ANMN/NRS/NRSMAI for all the files at Maria Island reference station. 

example (get all the files address from NRS Maria Island) : 

```
python catalog.py ANMN/NRS/NRSMAI >NRSMAI.txt
```

2. Run the `copyDataset.py` code with the [-v variables] argument and the list of [files] retrieved in 1

example (get the TEMP variable from all the instruments at NRS Maria Island): 

```
python copyDataset.py -v TEMP -f NRSMAI.txt
```



