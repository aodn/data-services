# Time Series aggregator

This code, developped by [Pete Jensen](https://github.com/petejan/imos-tools) collect data for selected variables for a particular site and produces a single ncdf file with all the variables for all deployments.

## Intructions to run

1. Retrieve the list of all the required files from the AODN THREDDS server using the `catalog.py` code. Go to the THREDDS catalog and select the correct path, e.g. ANMN/NRS/NRSMAI for all the files at Maria Island reference station.

2. Run the `copyDataset.py` code with the [-v variables] argument and the list of [files] retrieved in 1


