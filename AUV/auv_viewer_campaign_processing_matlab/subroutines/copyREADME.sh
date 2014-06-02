#!/bin/ksh
#copyREADME.sh
#Copy README_AUV_Data_Products.txt in each dive directory on the DataFabric
#sh copyREADME.sh "GBR201102"

##############################################################################################
##############################################################################################
##############################################################################################
AUV_MATLAB_CODE_FOLDER="/home/lbesnard/subversion/AUV_processing/trunk/AUV_MATLAB_CODE/subroutines/";
ARCS_FOLDER="/home/lbesnard/df_root/IMOS/public/AUV/";
CAMPAIGN=$1;
##############################################################################################
##############################################################################################
##############################################################################################

cd ${ARCS_FOLDER}${CAMPAIGN}
 for Dive in `ls -d r*/`
    do  
    cp -r ${AUV_MATLAB_CODE_FOLDER}"README_AUV_Data_Products.txt"  ${ARCS_FOLDER}${CAMPAIGN}"/"${Dive};   
done
