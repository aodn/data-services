# SOOP SST XBT ASF data processing
==================

### CRONTAB 
There is one entry for each data set
 * ``` $DATA-SERVICES/cron.d/SOOP_ASF_SST```
 * ``` $DATA-SERVICES/cron.d/SOOP_XBT```

### Usage

#### SOOP XBT
```bash
./SOOP_XBT_NRT.py -h      # Help
./SOOP_XBT_NRT.py -f      # Force reprocess all SBD files already in WIP
./SOOP_XBT_NRT.py         # Normal process
```

The ```-f``` option reprocess all the files and will push a manisfest file to
incoming_dir. This is fast reprocessing way if some cleaning needs to happen. 
Some manual cleaning would still need to be performed on the data storage and 
db eventually


#### SOOP ASF SST
```
./SOOP_BOM_ASF_SST.py        # pushes new files from bom ftp to incoming dir
./SOOP_BOM_ASF_SST.py -f     # pushes ALL files already dowloaded in wip to incoming dir for reprocessing
```

### Adding Vessels
To add a new vessel, please edit ```lib/python/ship_callsign```
