# Time Series aggregator

This script, developped originally by [Pete Jensen](https://github.com/petejan/imos-tools) collects data for selected variables for all instruments at a particular site and produces a single netCDF file with all the variables for all deployments.


## HOWTO run the script

```
python copyDataset.py --help
usage: copyDataset.py [-h] [-var VAR] [-site SITE] [-ts TIMESTART]
                      [-te TIMEEND] [--demo]

Concatenate ONE variable from ALL instruments from ALL deployments from ONE
site

optional arguments:
  -h, --help     show this help message and exit
  -var VAR       name of the variable to concatenate. Accepted var names:
                 TEMP, PSAL
  -site SITE     site code, like NRMMAI
  -ts TIMESTART  Start time like 2015-12-01. To be implemented
  -te TIMEEND    End time like 2018-06-30. To be implemented
  --demo         DEMO mode: TEMP at 27m, 43m, three deployments at NRSROT
```

## NOTES

- Please try it first in DEMO mode (`--demo`). 
- Then run it using very recent files. It will probably crash due to differences in the nc file format specieally in the older files. For the moment it has been tested with TEMP and PSAL only.
- Please report any problems






