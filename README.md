data-services
=============
A place to add Data Services scripts from PO's


# Folder stucture

The suggested naming convention we agreed on with the developpers, regarding the different PO's scripts was :
*[FACILITY_NAME]/[SUB-FACILITY_NAME]_[script_name]_[programing_language]*

example :
FAIMMS/faimms_data_rss_channels_process_matlab

# Injected Environment Variables

During deployment, the following environment variables will be available for
cronjobs, they may or may not be used. Using them will result in more
relocatable and robust scripts.

The environment variables are:

|Name              |Default                   |Purpose                        |
|------------------|--------------------------|-------------------------------|
|$OPENDAP_DIR      |/mnt/opendap              |OpenDAP                        |
|$PUBLIC_DIR       |/mnt/imos-t4/IMOS/public  |Public                         |
|$ARCHIVE_DIR      |/mnt/imos-t4/IMOS/archive |Archive                        |
|$INCOMING_DIR     |/mnt/imos-t4/IMOS/staging |Incoming                       |
|$OPENDAP_IMOS_DIR |$OPENDAP_DIR/1/IMOS       |IMOS OpenDAP                   |
|$PUBLIC_IMOS_DIR  |$PUBLIC_DIR               |IMOS public                    |
|$ARCHIVE_IMOS_DIR |$ARCHIVE_DIR              |IMOS archive                   |
|$WIP_DIR          |/mnt/ebs/wip              |Work In Progress tmp dir       |
|$DATA_SERVICES_DIR|/mnt/ebs/data-services    |Where this git repo is deployed|
|$LOG_DIR          |/mnt/ebs/log/data-services|Designated log dir             |

## Mocking Environment

In order to mock your environment so you can **test** things, you can have a
script called `env.sh` for example with the contents of:
```
export OPENDAP_DIR='/tmp/opendap'
export PUBLIC_DIR='/tmp/public'
export ARCHIVE_DIR='/tmp/archive'
export INCOMING_DIR='/tmp/incoming'
export OPENDAP_IMOS_DIR="$OPENDAP_DIR/1/IMOS"
export PUBLIC_IMOS_DIR="$PUBLIC_DIR"
export ARCHIVE_IMOS_DIR="$ARCHIVE_DIR"
export WIP_DIR='/tmp/wip'
export DATA_SERVICES_DIR="$PWD"
export LOG_DIR='/tmp/log'

mkdir -p $OPENDAP_IMOS_DIR $PUBLIC_IMOS_DIR $ARCHIVE_IMOS_DIR $WIP_DIR $LOG_DIR
```

Then to test your script with the mocked environment you can run:
```
$ (source env.sh && YOUR_SCRIPT.sh)
```

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

To create a crontab entry, you need to create a text file with the name of your choice (preferably something meaningfull) in the folder https://github.com/aodn/data-services/tree/master/cron.d

```bash
# m h  dom mon dow   command
# .---------------- minute (0 - 59)
# |  .------------- hour (0 - 23)
# |  |  .---------- day of month (1 - 31)
# |  |  |  .------- month (1 - 12) OR jan,feb,mar,apr ...
# |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat
# |  |  |  |  |
# *  *  *  *  * user-name  command to be executed
0 22  * * *  $username  script.path/script.sh
```
