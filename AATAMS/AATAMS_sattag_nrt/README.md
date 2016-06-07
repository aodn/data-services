# AATAMS SATTAG NRT
This script downloads all the NRT data from the GTS, extract the *.dat.gz files and convert individual Australian profiles only into CF compliant NetCDF file.

### usage
```bash
./aatams_nrt.py -h       Help
./aatams_nrt.py -f       Force reprocess dat files already in WIP
./aatams_nrt.py          Normal process
```

The ```-f``` option reprocess all the files and will push a manisfest file to
incoming_dir. This is fast reprocessing way
### CRON
in cron.d/AATAMS_sattag_nrt

### Contact
laurent.besnard@utas.edu.au

