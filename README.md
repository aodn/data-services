data-services
=============
A place to add Data Services scripts from PO's


# Folder stucture

The suggested naming convention we agreed on with the developpers, regarding the different PO's scripts was :
*[FACILITY_NAME]/[SUB-FACILITY_NAME]_[script_name]_[programing_language]*

example :
FAIMMS/faimms_data_rss_channels_process_matlab

# Configuration

Any path to the data, script, database ... should not be hard coded in the scripts. I (loz) suggest that we have a file called for example config.txt where all those values could be entered in. Then, the sys-admin can change the config file if needed

example of a config.txt file
```bash
## [PYTHON PATH location]
python.path			= /usr/bin/python
## [MATLAB bin location]
matlab.path			=/usr/local/bin/matlab
## script folder location
script.path			= /usr/local/bin/AUV/AUV_MATLAB_CODE
```
Some easy tools (python and matlab) already exists to read quickly those files

**MATLAB :**
see
https://github.com/aodn/data-services/blob/master/FAIMMS/faimms_data_rss_channels_process_matlab/subroutines/std/readConfig.m
```matlab
FAIMMS_DownloadFolder = readConfig('dataFAIMMS.path', 'config.txt','=');
```

**PYTHON :**
```python
from configobj import ConfigObj # to read a config file
        # we read here the database connection inputs
        config = ConfigObj('config.txt')            
        db_server = config.get('server.address')
        db_dbname = config.get('server.database')
```        
       
**R :**
```r
```

# Crontab

It could be good to add for every config.txt a crontab file. In such a way, the sys-admin would know when we want to launch our script, if it is supposed to run automatically, and which main script needs to be ran.
