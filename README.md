data-services
=============
A place to add Data Services scripts from PO's.  Data services are scripts which are used to process incoming data on a per pipeline basis in the data ingestion pipelines.


# Folder stucture

The suggested naming convention we agreed on with the developers, regarding the different PO's scripts was :
*[FACILITY_NAME]/[SUB-FACILITY_NAME]_[script_name]*

example :
FAIMMS/faimms_data_rss_channels_process

# Injected Environment Variables

During the deployment of data services (see [chef recipe](https://github.com/aodn/chef/blob/eb1535192b526ca775fa557630d3221187e766c7/cookbooks/imos_po/recipes/data_services.rb#L131)), various environment variables are made available for
cronjobs (they may or may not be used). Using them will result in more
relocatable and robust scripts.

The environment variables are:

|Name |Default | Purpose|
|:--|:--|:--|
| $ARCHIVE_DIR | /mnt/ebs/archive | Archive |
| $ARCHIVE_IMOS_DIR | /mnt/ebs/archive | Archive |
| $INCOMING_DIR | /mnt/ebs/incoming |Incoming |
| $ERROR_DIR | /mnt/ebs/error | Dir. to store incoming files that cause pipeline errors |
| $WIP_DIR | /mnt/ebs/wip |Work In Progress tmp dir |
| $DATA_SERVICES_DIR | /mnt/ebs/data-services | Where this git repo is deployed |
| $DATA_SERVICES_TMP_DIR | nil | |
| $EMAIL_ALIASES | /etc/incoming-aliases | List of configured aliases |
| $PYTHONPATH | $DATA_SERVICES_DIR/lib/python | Location of data-services python scripts/modules |
| $LOG_DIR | /mnt/ebs/log/data-services | Designated log dir |
| $HARVESTER_TRIGGER | sudo -u talend /mnt/ebs/talend/bin/talend-trigger -c /mnt/ebs/talend/etc/trigger.conf | Command to trigger talend |
| $S3CMD | s3cmd --config=/mnt/ebs/data-services/s3cfg | Default parameters for the s3cmd utility |
| $S3_BUCKET | | Location of the S3 bucket for this environment |

It may be necessary to source additional environment variables that are defined elsewhere. For example, the location of the schema definitions which are defined in the pipeline databags can be sourced from /etc/profile.d/pipeline.sh.

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

# Cronjobs

Cronjobs for data-services scripts are managed via chef databags under ``chef-private/data_bags/cronjobs``

Cronjobs are be prefixed with ``po_`` in order to differentiate them from other non pipeline-related tasks.

The cronjob must source any necessary environment variables first, followed by your command or script e.g.:

``` bash
0 21 * * * projectofficer source /etc/profile && $DATA_SERVICES_DIR/yourscript.py
```

Example data_bag. ``chef-private/data_bags/cronjobs/po_NRMN.json``

``` json
{
  "job_name": "po_NRMN",
  "shell": "/bin/bash",
  "minute": "0",
  "hour": "21",
  "user": "projectofficer",
  "command": "source /etc/profile; $DATA_SERVICES_DIR/NRMN/extract.sh",
  "mailto": "benedicte.pasquer@utas.edu.au",
  "monitored": true
}
```

The following attributes can be used:

<table>
  <tr>
    <th>Key</th>
    <th>Type</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td>['job_name']</td>
    <td>String</td>
    <td>The ID/name of the cronjob (mandatory)</td>
    <td></td>
  </tr>
  <tr>
    <td>['shell']</td>
    <td>String</td>
    <td>The shell to use for the script/command (mandatory)</td>
    <td></td>
  </tr>
  <tr>
    <td>['user']</td>
    <td>String</td>
    <td>User that will run the script/command (mandatory)</td>
    <td></td>
  </tr>
  <tr>
    <td>['command']</td>
    <td>String</td>
    <td>Command or script to be run (must be valid bash and must be able to resolve path)</td>
    <td></td>
  </tr>
  <tr>
    <td>['mailto']</td>
    <td>String</td>
    <td>User to send report of cronjob command output to</td>
    <td>root@localhost</td>
  </tr>
  <tr>
    <td>['monitored']</td>
    <td>Boolean</td>
    <td>Determines whether Nagios will monitor the job or not</td>
    <td></td>
  </tr>
  <tr>
    <td>['minute']</td>
    <td>String</td>
    <td>minute to run job on (see crontab syntax below)</td>
    <td>*</td>
  </tr>
  <tr>
    <td>['hour']</td>
    <td>String</td>
    <td>hour to run job on (see crontab syntax below)</td>
    <td>*</td>
  </tr>
  <tr>
    <td>['day']</td>
    <td>String</td>
    <td>day to run job on (see crontab syntax below)</td>
    <td>*</td>
  </tr>
  <tr>
    <td>['month']</td>
    <td>String</td>
    <td>month to run job on (see crontab syntax below)</td>
    <td>*</td>
  </tr>
  <tr>
    <td>['weekday']</td>
    <td>String</td>
    <td>weekday to run job on (see crontab syntax below)</td>
    <td>*</td>
  </tr>
</table>

### Crontab syntax:

``` bash
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


Your cronjobs need to be defined in the node attributes of the chef-managed node before they will be installed. e.g.:

``` json
  "cronjobs": [
    "po_NRMM",
    "po_someother_job",
    "..."
  ]
```
