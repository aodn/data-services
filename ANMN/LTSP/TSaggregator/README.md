# Time Series aggregator

This script, developped originally by [Pete Jensen](https://github.com/petejan/imos-tools) collects data for selected variables for all instruments at a particular site and produces a single netCDF file with all the variables for all deployments.



## HOWTO run the script

`python copyDataset.py -var TEMP -site NRSROT -ts 2018-01-01 -te 2019-05-01`

Concatenate TEMP for NRSROT deployments since 2018-01-01 thru 2019-05-01

use the argument `--help` to get help

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
  -ts TIMESTART  Start time like 2015-12-01
  -te TIMEEND    End time like 2018-06-30
  --demo         DEMO mode: TEMP at 27m, 43m, three deployments at NRSROT
```
