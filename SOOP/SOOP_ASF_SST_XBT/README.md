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
./SOOP_BOM_ASF_SST.py              # pushes new files from bom ftp to incoming dir
./SOOP_BOM_ASF_SST.py -f           # pushes ALL files already dowloaded in wip to incoming dir for reprocessing, equivalent to ./SOOP_BOM_ASF_SST.py -r '*'
./SOOP_BOM_ASF_SST.py -r *FHZI*    # pushes ALL files already dowloaded in wip and matching a certain regexp patter to incoming dir for reprocessing. In this case, the ship code
./SOOP_BOM_ASF_SST.py -r *201604*
./SOOP_BOM_ASF_SST.py -r *ASF-MT*
./SOOP_BOM_ASF_SST.py -r *SOOP-SST*
./SOOP_BOM_ASF_SST.py -r '*FMT*VLMJ*'
./SOOP_BOM_ASF_SST.py -d -r '*FMT*VLMJ*'  # performs a dry-run only
```

### Adding Vessels
Adding a vessel is done automatically with platform vocabulary available at 
https://s3-ap-southeast-2.amazonaws.com/content.aodn.org.au/Vocabularies/platform/aodn_aodn-platform-vocabulary.rdf
