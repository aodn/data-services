% Process and Validate Ocean Colour products (SRS-OC-PVOC) 
% This activity will see the implementation of the processing chain for NASA/ESA standard 
% OC products and of Primary Productivity algorithms for the entire Australian sector to 
% enable delivery through AoDAAC/eMII of ocean colour data products for the Australian 
% region with a characterized uncertainty
% 
% Process and Validate Ocean Colour products (SRS-OC-PVOC) 
% This activity will establish a data handling and processing chain, focussing on using standard 
% NASA/ESA algorithms for Case 1 waters by utilising wherever possible the resources managed 
% by ARCS (part of the NCRIS Platforms for Collaboration capability). Existing published primary 
% productivity algorithms will be implemented to produce a first estimate of this parameter for the 
% Southern Ocean. The extraction and processing of a match-up database to the bio-optical 
% data base  will be essential to assess the uncertainty in these global products and to ensure a 
% seamless transition between the products derived from the current generation of sensors 
% (SeaWiFS/ MODIS/MERIS, see Table 1). 
% The provisioning of the PVOC will involve: 
% • Establish a data handling and processing chain, focussing on using standard NASA/ESA 
% algorithms for Case 1 waters and utilising wherever possible the resources managed by 
% ARCS (part of the NCRIS Platforms for Collaboration capability); 
% • Implement existing published primary productivity algorithms to produce a first estimate of 
% this parameter for the Southern Ocean. 
% • Characterise uncertainty for these products through the extraction and processing of a 
% match-up database. A match-up analysis will be carried out on historical and continuing 22 
% satellite imagery for NASA's MODIS AQUA & TERRA, SeaWIFS and ESA's MERIS. The 
% assessment of accuracies for satellite ocean colour products will be run at different levels: 
% • Water leaving radiance (or reflectance) and Atmospheric Optical Thickness: using 
% SEAPRISM data acquired at LJCO we will characterize the accuracy of the 
% Atmospheric correction algorithms for Australian conditions. 
% • Inherent Optical properties: using instruments data collected with ACs+BB9 (at 
% LJCO+ legacy data), with the WQM+ECOtriplets (at the NRS moorings and on the 
% ANFOG gliders) we will assess the accuracy of the algorithms for the retrieval of  
% optical properties from Ocean colur data (i.e. absorption and scattering, apportioned 
% to Phytoplankton, Coloured Dissolve organic matter and non-algal particulate 
% matter) 
% • Concentrations of optically active substances: using the direct sampling of 
% chlorophyll, coloured dissolved organic matter and particulate matter (IMOS + 
% legacy data) we will assess the accuracy of ocean colour algorithms for the retrieval 
% of such biogeochemical quantities. 
% This activity will ensure a seamless transition between the products derived from the current 
% generation of sensors (SeaWiFS/ MODIS/MERIS) to the next generation, enabling the delivery 
% of National Ocean Colour products through AO-DAAC/eMII with a characterized uncertainty for 
% Australian waters. This would raise this status of ocean colour satellite data to Environmental 
% Data Records.

% http://imos.org.au/fileadmin/user_upload/shared/IMOS%20General/EIF/Final_Project_Plans/11_SRS_2010-13_IMOS_EIF_Facility_Project_Plan.pdf

global DataFileFolder
global FacilitySuffixe
global DataType

WhereAreScripts=what;
Toolbox_Matlab_Folder=WhereAreScripts.path;                  
addpath(genpath(Toolbox_Matlab_Folder));

downloadPHYPIG_files;
FacilitySuffixe='IMOS_ANMN-NRS'; %ocean color Primary Productivity algorithms
DataType='X';  %<Data-Code> New convention for marginal parameters
DataFileFolder='/home/lbesnard/Bio_WIP/ToConvert/PhytoPlankton';

Nsheet=1; %number of working sheet in the xls file
%% convert xls in csv
% have to convert the xls file manualy in case of bug as a
% csv with OpenOFFICE,UTF8 delimiter column '|' no delimiter text
% each sheet has to be saved in a separate csv file
% need catdoc on linux package sudo apt-get install catdoc
% FilesXLS=DIRR(DataFileFolder,'.xls');
[~,~,FilesXLS]=DIRR(DataFileFolder,'.xls','name','isdir','1');
for ii=1:length(FilesXLS)
    filename=char(FilesXLS(ii));
%     xls2csv_CATDOC_NSheet(filename,Nsheet)
    xls2csv_PERL_NSheet(filename,Nsheet)
end
% if there is a bug at this stage, have to save the xls file manualy as a
% csv with OpenOFFICE, delimiter column '|' no delimiter text



%% create the NetCDF file
[~,~,FilesCSV]=DIRR(DataFileFolder,'.csv','name','isdir','1');
% FilesCSV=dir (strcat(DataFileFolder,'*.csv*'));
for ii=1:length(FilesCSV)
%     filename=fullfile(DataFileFolder,char(FilesCSV(ii)));
    filename=char(FilesCSV(ii));

    try
        [DATA,METADATA]=NRS_Phytoplankton_reader(filename);
        NCfileName=CreatePhytoplankton_NetCDF(DATA,METADATA);
        [SourceFolder,SourceName]=fileparts(filename);
        ConvertedFolder=SourceFolder(length(DataFileFolder)+1:end);
        if ~exist(fullfile(DataFileFolder,'NetCDF',ConvertedFolder),'dir')
         mkdir(fullfile(DataFileFolder,'NetCDF',ConvertedFolder))
        end
        movefile(fullfile(DataFileFolder,'NetCDF',NCfileName),fullfile(DataFileFolder,'NetCDF',ConvertedFolder,NCfileName))
        delete(filename)
      
        clear ConvertedFolder  SourceFolder SourceName NCfileName
    catch
        disp(char(FilesCSV(ii)))
        disp('if there is a bug at this stage, have to save the xls file manualy as a csv with OpenOFFICE, delimiter column | no delimiter text')
        disp('save manually the file then reload part of this script')
    end
end

%% create the PSQL script to load by looking in the NetCDF folder.
% FilesNC=dir (strcat(DataFileFolder,'NetCDF/*.nc'));
[~,~,FilesNC]=DIRR(fullfile(DataFileFolder,'NetCDF'),'.nc','name','isdir','1');

% for ii=1:length(FilesNC)
%         NCfile=char(FilesNC(ii));
%     CreateBioOptical_Pigment_SQL(NCfile)
% end
% 
% %% create Plots
% for ii=1:length(FilesNC)
%         NCfile=char(FilesNC(ii));
% plot_OC_phytoplankton(NCfile)
% end