# ANMN Time Series aggregator

This script, developped originally by [Pete Jansen](https://github.com/petejan/imos-tools), collects data for a selected variable from all instruments at a particular site between selected dates, and outputs a single netCDF file with the selected variable concatenated from all deployments. It also outputs a text file with the details of the selected files.



## HOWTO run the script

`python copyDataset.py -var TEMP -site NRSROT -ts 2018-01-01 -te 2019-05-01`

Concatenate TEMP from NRSROT deployments from 2018-01-01 thru 2019-05-01

use the argument `--help` to get help

```
python copyDataset.py --help
usage: copyDataset.py [-h] [-var VAR] [-site SITE] [-ts TIMESTART]
                      [-te TIMEEND] [-out OUTFILELIST] [--demo]

Concatenate ONE variable from ALL instruments from ALL deployments from ONE
site

optional arguments:
  -h, --help        show this help message and exit
  -var VAR          name of the variable to concatenate. Accepted var names:
                    TEMP, PSAL
  -site SITE        site code, like NRMMAI
  -ts TIMESTART     start time like 2015-12-01. Default 1944-10-15
  -te TIMEEND       end time like 2018-06-30. Default today's date
  -out OUTFILELIST  name of the file to store the selected files info.
                    Default: fileList.csv
  --demo            DEMO mode: TEMP at 27m, 43m, three deployments at NRSROT
```
