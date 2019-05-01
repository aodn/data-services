# Time Series aggregator

This code, developped by [Pete Jensen](https://github.com/petejan/imos-tools) collect data for selected variables for a particular site and produces a single ncdf file with all the variables for all deployments.

## Intructions to run

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



