# AATAMS_sattag_dm

AATAMS_sattag_dm processes the delayed mode data from the AATAMS project.



The data, in microsoft access database (MDB) format comes from another service to the IMOS data storage. This script processes the MDB files and create single netcdf files per profile.
The data is afterwards rsynced to the IMOS opendap folder.

### Usage
Type in your shell ```./AATAMS_sattag_dm_main.sh```

For for debugging, launch ```read_env``` function from ```./AATAMS_sattag_dm_main.sh``` prior to start MATLAB. This loads the environmnental variables.

### CRONJOB

in $DATA_SERVICES/cron.d/AATAMS_sattag_dm

### Contact
laurent.besnard@utas.edu.au
