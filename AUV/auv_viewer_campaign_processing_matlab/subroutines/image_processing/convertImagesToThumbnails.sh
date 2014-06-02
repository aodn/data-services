#!/bin/ksh
# convertImagesToThumbnails.sh

#Just give the exact RELEASED_CAMPAIGN_FOLDER of the AUV folder, the script will harvest all the campaignFolderName and dives at once by itself
#It will create thumbnails in the DATA_OUTPUT_FOLDER folder. This images will have to be moved to imos2 then.
#This program has been written to be run separately from the main MATLAB code, in case some folders have to be reprocessed
##############################################################################################
##############################################################################################
##############################################################################################
RELEASED_CAMPAIGN_FOLDER="/media/POSTAL_2/RELEASE_DATA/";
DATA_OUTPUT_FOLDER="/media/Laurent_emII/TIFF2JPG/"; #local Work In Progress folder to save the created file
##############################################################################################
##############################################################################################
##############################################################################################

cd ${RELEASED_CAMPAIGN_FOLDER}

#goes into each single campaignFolderName folder
for campaignFolderName in `ls -d */`
do

    cd $campaignFolderName
    WIP="${DATA_OUTPUT_FOLDER}${campaignFolderName}";
    mkdir -p $WIP;
    WIP="${DATA_OUTPUT_FOLDER}${campaignFolderName}";

#goes into each single dive folder, starting with the r letter
    for Dive in `ls -d r*/`
    do 
	JPG_pre="i2jpg/";	
	JPG="${WIP}${Dive}${JPG_pre}";
	
	
	cd ${Dive};
	mkdir ${WIP}${Dive}
	mkdir $JPG;
	cd i2*gtif;
 

	for i in `ls *.tif `
	do
	    convert -resize 453x341 -quality 85 -unsharp 1.5×1.0+1.5+0.02 $i ${JPG}${i%tif}jpg    ;
	done
	cd ../..
    done
    cd ..
done
