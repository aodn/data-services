SOOP Tropical Research Vessel - download
=============

This script downloads data from the AIMS web service for the 
SOOP TRV sub facility

Installation
System requirements
Upgrade and compatibility issues
New features
Fixed issues
Tips
Contact Support

# Installation ==
1. This script is found in the data services repo, 
see https://github.com/aodn/data-services/tree/master/SOOP/SOOP_TRV_aims_download_process_matlab
-script.path 					:location of the scripts (from the checkout)
-python.path 					:location of the python binary
-matlab.path 					:location of the matlab binary
-dataSoop.path	 				:location of the scripts output (log + data)
-destination.path 				:location of the opendap folder where data is available to the public
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
