SOOP Tropical Research Vessel
=============

This script downloads data from the AIMS web service for the SOOP TRV sub facility.

Two vessels are processed :
 * Cape Ferguson
 * RV Solander


## Usage
Type in your shell ```./soop_trv.py```

## Data debug
A test is in place for each run of the script. We download a part of a channel, 
run a md5 checksum and compare with what we should have. 
If the md5 value is different, the script won't run. This test is necessary as 
we had in the past unwanted changes from AIMS. 
If this happens, go to $WIP_DIR/script_output_dir, and manually check the 
vimdiff of the ncdump output of the nc_unittest_* files.

## System Requirements
Python:
see requirements.txt

Operating System Support:
POBOX

## Contact Support
for support contact:
Email: laurent.besnard@utas.edu.au
