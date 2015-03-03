# SOOP SST XBT ASF data processing
==================

Phil's ancient set of scripts from the days of the Data Fabric and before the reign of talend.

# Usage
type ```./main.sh XBT``` or ```./main.sh ASF_SST``` to download and process XBT data or ASF_SST data from BOM.

# CRONTABE
There is one entry for each data set
 * ``` $DATA-SERVICES/cron.d/SOOP_ASF_SST```
 * ``` $DATA-SERVICES/cron.d/SOOP_XBT```i

# Adding Vessels
To add a new vessel to process, please edit either soop_xbt_realtime_processSBD.py or soop_bom_asf_sst_Filsort.py.
Edit self.ships and replace any space character with '-' 
