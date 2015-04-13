# SRS SST marvl product 

This script creates subsets of the L3S 1d night product, keeping the data at the isobath 500m around Australia and Quality Level of 5.

There is no automation, no cron at this stage. Since the data is not available on NSP10 at the time of writing the code, this has to run from nec10.

### Usage
run Matlab and launch 
```matlab
process_l3s_1d_night_marvl.m
```

### Contact
laurent.besnard@utas.edu.au
