data-services
=============
A place to add Data Services scripts from PO's


# Folder stucture

The suggested naming convention we agreed on with the developers, regarding the different PO's scripts was :
*[FACILITY_NAME]/[SUB-FACILITY_NAME]_[script_name]*

example :
FAIMMS/faimms_data_rss_channels_process

# Injected Environment Variables

During deployment, the following environment variables will be available for
cronjobs, they may or may not be used. Using them will result in more
relocatable and robust scripts.

The environment variables are:

|Name              |Default                    |Purpose                        |
|------------------|---------------------------|-------------------------------|
|$ARCHIVE_DIR      |/mnt/ebs/archive           |Archive                        |
|$INCOMING_DIR     |/mnt/ebs/incoming          |Incoming                       |
|$WIP_DIR          |/mnt/ebs/wip               |Work In Progress tmp dir       |
|$DATA_SERVICES_DIR|/mnt/ebs/data-services     |Where this git repo is deployed|
|$LOG_DIR          |/mnt/ebs/log/data-services |Designated log dir             |

## Mocking Environment

In order to mock your environment so you can **test** things, you can have a
script called `env.sh` for example with the contents of:
```
export ARCHIVE_DIR='/tmp/archive'
export INCOMING_DIR='/tmp/incoming'
export WIP_DIR='/tmp/wip'
export DATA_SERVICES_DIR="$PWD"
export LOG_DIR='/tmp/log'

mkdir -p $ARCHIVE_DIR $INCOMING_DIR $WIP_DIR $LOG_DIR
```

Then to test your script with the mocked environment you can run:
```
$ (source env.sh && YOUR_SCRIPT.sh)
```

# Configuration

# Crontab

To create a crontab entry, you need to create a text file with the name of your choice (preferably something meaningfull) in the folder data-services/cron.d

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
