NRS AIMS Darwin Yongala Beagle realtime data download
=============

This script downloads data from the AIMS web service and modify the netcdf files to be
CF and IMOS compliant. The data is NRT, and comes from the following stations : Darwin, Yongala and Beagle.
The script can be run as many times as desired.


## Installation

Open config.txt to change the paths of :
* data_wip_path                    :location of the NRS scripts output (log + data)

For testing on local machine, please edit $DATA_SERVICE_REPO/env

## Usage

Type in your shell ```./NRS.sh```


## Delete platform or channel for re-download/re-process
```bash
$ export data_wip_path=$WIP_DIR/ANMN/NRS_AIMS_Darwin_Yongala_data_rss_download_temporary
$ cd $DATA_SERVICES_DIR/lib/aims
$ mkdir $WIP_DIR/ANMN/NRS_AIMS_Darwin_Yongala_data_rss_download_temporary/.bckp
# backup pickle files 
cp $WIP_DIR/ANMN/NRS_AIMS_Darwin_Yongala_data_rss_download_temporary/*.pickle $WIP_DIR/ANMN/NRS_AIMS_Darwin_Yongala_data_rss_download_temporary/.bckp
$ ipython                                                                
```

Then in the python console
```python
# delete all entries from pickle file (qc level 0 and 1) for the platform Beagle
from realtime_util import delete_platform_entries_from_pickle
delete_platform_entries_from_pickle(0, 'Beagle')
delete_platform_entries_from_pickle(1, 'Beagle')

# also can delete a specific channe
from realtime_util import delete_channel_id_from_pickle
delete_channel_id_from_pickle(0, '261')
```


Files need to be removed from s3 bucket storage(remove ```echo``` and ```head -1``` once happy
```bash
for f in `s3_ls_recur IMOS/ANMN/NRS/REAL_TIME/NRSBEA/ | head -1` ; do
    echo po_s3_del $f
done
```

## Contact Support
for support contact:
Email: laurent.besnard@utas.edu.au
