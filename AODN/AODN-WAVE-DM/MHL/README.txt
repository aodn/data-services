Processing of Wave and temperature data from Manly Hydraulics.
For Wave data: process file with input for global attributes from netcdf file located in directory /input or from site dependant config files located in this folder.
Also reads in historical information stored in csv file located under History.
Input data stored in files called either *.TXT or *_new.txt under /TXTFILESprocess file run :
./process_MHLwave_from_txt.py  "/vagrant/tmp/MHL/TXTFILES/*_new.txt"
- Attention to run it with .TXT and .txt

Procedure is the same for temperature data 
excepc that no information is inputed for original netcdfs

Update April 2018
open ipython and run:
run process_MHLsst_from_txt.py /vagrant/tmp/MHL/input/SYDSSTIMOS19.txt 

Update December 2018
Changes in realtion to the creation of the NAtional Wave archive:
- Change Wave filenaming to be consistent with Wave archive data sets  
- Update of variable names
