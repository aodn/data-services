The files in this folder form part of the data 'product'
from the IMOS AUV Facility Sirius AUV operated by the
University of Sydney's Australian Centre for Field
Robotics.

The directory contains a number of different file types. These
are listed below. The 'product' from each dive is contained in
it's own named folder.


*all_reports folder:-
     This folder contains the PDF short dive report files, one
     for each of the dives. These contain some summary graphs and
     sample images.

*per_dive folder:-
  -> i*_gtif (contains geotif versions of all images).
  -> i*_subsampN (subsampled geotif images (one in N, and a csv of locations).
  -> hydro_netcdf (*.nc files, netcdf files containing CT and ecopuck data).
  -> track_files  (dive track in csv, kml and arcgis shape file format).
  -> mesh (3D reconstuction of the dive, needs OSG viewer software).
  -> multibeam (a number of different versions of the multibeam product).
      *.gsf: Navigated and automatically cleaned swath 
        bathymetry with raw intensity data.  
        Format specification 121 (SAIC Generic Sensor Format) 
        in mbsystem.
      *.grd: Gridded bathymetry.  NetCDF format as used 
        with GMT.  Use grdinfo to determine resolution 
        and projection.
      *.grd.pdf: Plotted gridded bathymetry (local northings and eastings)
        acrobat PDF format.


Windows Viewers folder:-
     This folder contains a copy of gqview a windows image viewer that is 
     able to view the geotiffs. These are standard tiff's but with jpg 
     compression, and the regular windos viewer will not open. Other more 
     capable windows programs including AcDsee (spelling???) also work.
     Ultimately there should be a copy of the windows viewer for the meshes
     but this is not yet here.

Acknowledgement:-
"Data was sourced from the Integrated Marine Observing System (IMOS). An 
initiative of the Australian Government being conducted as part of the 
National Collaborative Research Infrastructure Strategy".

Distribution Statement:-
"AUV data may be reused, provided that related metadata explaining the data 
has been reviewed by the user, and the data is appropriately acknowledged. 
Data products and services from IMOS are provided "as is" without any warranty 
as to fitness for a particular purpose". 

Further Information:-
For further information, contact the AUV Facility leader
Dr. Stefan B. Williams
Australian Centre for Field Robotics
Rose St Bldg J04
University of Sydney
Sydney, NSW
2006, Australia

e-mail: auv@acfr.usyd.edu.au
phone: (02) 9351 8152


 

