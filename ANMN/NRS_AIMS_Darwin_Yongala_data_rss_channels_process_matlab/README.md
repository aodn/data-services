NRS_AIMS_Darwin_Yongala_data_rss_channels_process_matlab
=============

This script downloads data from the AIMS web service. The 
data is NRT, and comes from two different stations : Darwin 
and Yongala. The script can be run as many times as desired.



Installation
System requirements
Upgrade and compatibility issues
New features
Fixed issues
Tips
Contact Support

# Installation ==
1. This script is found in the data services repo, 
see https://github.com/aodn/data-services/tree/master/ANMN/NRS_AIMS_Darwin_Yongala_data_rss_channels_process_matlab
2. Open config.txt to change the paths of :
-script.path 					:location of the scripts (from the checkout)
-python.path 					:location of the python binary
-matlab.path 					:location of the matlab binary
-dataWIP.path	 				:location of the NRS scripts output (log + data)
-destinationProductionData.path :location of the opendap folder where data is available to the public
-dataOpendapRsync.path  		:location of the source data folder which will be rsynced to opendap
-logFile.name 					:name of the log file
-email1.log	 					:email logfile user1
-email2.log  					:email logfile user2 (not required)
3. Execute the program by typing in your shell ```bash NRS.sh```

Note that this should be chef'ised' in the future, and monitored with NAGIOS

# System Requirements ==
Internet connection
Tested with MATLAB R2009a, R2012a
install the python module  from http://pypi.python.org/pypi/configobj/ . 1 wget *zip, unzip *.zip, python setup.py install 


Operating System Support
The following operating systems are supported:
Ubuntu 9.10, MINT16


== Upgrade Issue Heading ==


== New Features Added ==


== Fixed Issues ==


== Tips ==

== Contact Support ==
for support contact:
Email: laurent.besnard@utas.edu.au
