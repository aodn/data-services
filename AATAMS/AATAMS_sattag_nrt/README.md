# AATAMS_sattag_nrt

AATAMS_sattag_nrt processes the near real time data from the AATAMS project.


The data is uploaded from another service to the IMOS data storage as *.dat files. This script processes the dat files and create single netcdf files per profile, as well as aggregated files per tag.
The data is afterwards rsynced to the IMOS opendap folder.

### Usage
Type in your shell ```./AATAMS_sattag_nrt_main.sh```

For for debugging, launch ```read_env``` function from ```./AATAMS_sattag_nrt_main.sh``` prior to start MATLAB. This loads the environmnental variables.



### CRON

in $DATA_SERVICES/cron.d/AATAMS_sattag_nrt

### Contact
laurent.besnard@utas.edu.au

