function AUV_Reporting()
%% AUV_Reporting
% this function aims to help writing a detailled report per campaign. It
% checks the existence of different datasets per campaign / dive. A csv
% file 'auvReporting.csv' is then created in processedDataOutputPath. The
% content of this csv file can then be copied quickly and manually to the
% excel spreadsheet called AUV_audit_....xlsx for a better visualisation.
% The excel file needs to be filled with more information, but the long
% task of checking if everything is here is quickly made by this program.
% The excel file is a working file for both the eMII project officer and
% the AUV team to be sure NO data is actually missing.
%
% Inputs:
%        config.txt  :Only campaigns available locally
%
% Outputs:
%   auvReporting.csv :to copy and paste in AUV_audit_....xlsx
%
% Author: Laurent Besnard
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Oct 2012; Last revision: 31-Oct-2012

%%  script location
WhereAreScripts = what;
scriptPath      = WhereAreScripts.path;
addpath(genpath(scriptPath));
configFile      = dir('config*.txt');

for cc = 1:length(configFile)
    releasedCampaignPath        = readConfig('releasedCampaign.path', configFile(cc).name,'=');
    processedDataOutputPath     = readConfig('processedDataOutput.path', configFile(cc).name,'=');
    mkpath(processedDataOutputPath)
    
    %% These are the names of the campaign folder
    campaignName = textscan(readConfig('campaignNameReport', configFile(cc).name,'='),'%s','delimiter',',');
    campaignName = campaignName{1};
    campaignName = campaignName(~cellfun('isempty',campaignName));
    
    Filename_AUV_reporting = strcat(processedDataOutputPath,filesep,'auvReporting.csv');%% csv file to copy to the excel spreadsheet
    if exist(Filename_AUV_reporting,'file') == 2
        delete(Filename_AUV_reporting)
    end
    
    %%  Proccess all the campaings
    for k = 1:length(campaignName)
        campaignToProcess = cell2mat(campaignName(k));
        Dives  = dir(strcat(releasedCampaignPath,filesep,campaignToProcess,filesep,'r*'));
        nDives = length(Dives);
        
        %%  Proccess all the dives of the k campaing
        for t = 1:nDives
            
            
            diveToProcess = char(Dives(t,1).name);
            fprintf('%s - Campaign: "%s" - Dive: "%s" currently processed for Reporting\n',datestr(now),campaignToProcess,diveToProcess)
            
            sample_data_file = strcat(processedDataOutputPath,filesep,campaignToProcess,filesep,'sample_data_',diveToProcess,'.mat');
            if exist(sample_data_file,'file') == 2
                load (sample_data_file, '-mat')
                nImages = length(sample_data);
                clear sample_data_file sample_data
            else
                divePath      = (strcat(releasedCampaignPath,filesep,campaignToProcess,filesep,diveToProcess));
                TIFF_dir      = dir([divePath filesep 'i2*gtif']);
                tiffPath      = [divePath filesep TIFF_dir.name];
                
                list_images   = dir([tiffPath filesep '*LC16.tif']);
                nImages       = length(list_images);
            end
            
            %% metadata uuid
            try
                uuid = getUUID([campaignToProcess filesep diveToProcess],...
                    fullfile(processedDataOutputPath,filesep,...
                    readConfig('metadataUUID.file', configFile(cc).name,'=')),',');
            catch
                uuid='n.a.';
            end
            
            
            %% DiveReport
            DiveReport = dir(strcat(releasedCampaignPath,filesep,campaignToProcess,filesep,'all_reports',filesep,diveToProcess,'_report.pdf'));
            if size(DiveReport,1) > 0
                isDiveReportExist = 'YES';
            else
                isDiveReportExist = 'NO';
            end
            
            %% Multibeam
            multibeamFiles = rdir(strcat(releasedCampaignPath,filesep,campaignToProcess,filesep,diveToProcess,filesep,'multibeam/**/*.grd'));
            if size(multibeamFiles,1) > 0
                ismultibeamFilesExist = 'YES';
            else
                ismultibeamFilesExist = 'NO';
            end
            
            %% mesh
            meshFiles = rdir(strcat(releasedCampaignPath,filesep,campaignToProcess,filesep,diveToProcess,filesep,'mesh/*.ive'));
            if size(meshFiles,1) > 0
                ismeshFilesExist = 'YES';
            else
                ismeshFilesExist = 'NO';
            end
            
            %% csv
            csvFile = rdir(strcat(releasedCampaignPath,filesep,campaignToProcess,filesep,diveToProcess,filesep,'track_files/*.csv'));
            if size(csvFile,1) > 0
                % have to check if the csv is corrupted or NOt, so we try to
                % import it
                try
                    [~, dataCSV]   = csvload(csvFile.name);%if NO error ir then csv file exist
                    iscsvFileExist = 'YES';
                catch
                    iscsvFileExist = 'NO';%else it does NOt or it is corrupted
                end
                
            else
                iscsvFileExist = 'NO';
            end
            
            
            
            % comparing number of images processed and what is written CSV
            % track
            if exist('dataCSV','var')
                maxImage = max(nImages,size(dataCSV{1,1},1));
                minImage = min(nImages,size(dataCSV{1,1},1));
                
                if (maxImage == minImage)
                    % images missing somewhere
                    isAllImagesThere = 'ALL_IMAGES';
                else
                    isAllImagesThere = [num2str(minImage) '/' num2str(maxImage)];
                end
            else
                if nImages==0
                    isAllImagesThere = 'NONE';
                else
                    isAllImagesThere = num2str(nImages);
                end
            end
            
            %% NETCDF , check all variables
            fid_ST = rdir(strcat(releasedCampaignPath,filesep,campaignToProcess,filesep,diveToProcess,filesep,'hydro_netcdf/IMOS_AUV_ST_*.nc'));
            
            if size(fid_ST,1)>0
                try
                    ncid_ST = netcdf.open(fid_ST(1).name,'NC_NOWRITE');
                catch
                    isTEMPexist = 'NO';
                    isPSALexist = 'NO';
                end
                
                
                %TEMP
                try
                    [TEMP_ST,~] = getVarNetCDF('TEMP',ncid_ST);
                    if sum(isnan(TEMP_ST)) ~= length(TEMP_ST)
                        isTEMPexist = 'YES';
                    else
                        isTEMPexist = 'NO';
                    end
                catch
                    isTEMPexist = 'NO';
                end
                
                
                %PSAL
                try
                    [PSAL_ST,~] = getVarNetCDF('PSAL',ncid_ST);
                    
                    %psal
                    if sum(isnan(PSAL_ST)) ~= length(PSAL_ST)
                        isPSALexist = 'YES';
                    else
                        isPSALexist = 'NO';
                    end
                catch
                    isPSALexist = 'NO';
                end
                
                %temp
                try
                    netcdf.close(ncid_ST)
                end
            else
                isTEMPexist = 'NO';
                isPSALexist = 'NO';
            end
            
            fid_B = rdir(strcat(releasedCampaignPath,filesep,campaignToProcess,filesep,diveToProcess,filesep,'hydro_netcdf/IMOS_AUV_B_*.nc'));
            if size(fid_B,1) > 0
                try
                    ncid_B = netcdf.open(fid_B(1).name,'NC_NOWRITE');
                catch
                    isCDOMexist = 'NO';
                    isCPHLexist = 'NO';
                    isOPBSexist = 'NO';
                end
                
                %CDOM
                try
                    [CDOM_B,~] = getVarNetCDF('CDOM',ncid_B);
                    if sum(isnan(CDOM_B)) ~= length(CDOM_B)
                        isCDOMexist = 'YES';
                    else
                        isCDOMexist = 'NO';
                    end
                catch
                    isCDOMexist = 'NO';
                end
                
                %CPHL
                try
                    [CPHL_B,~] = getVarNetCDF('CPHL',ncid_B);
                    
                    if sum(isnan(CPHL_B)) ~= length(CPHL_B)
                        isCPHLexist = 'YES';
                    else
                        isCPHLexist = 'NO';
                    end
                catch
                    isCPHLexist = 'NO';
                end
                
                %OPBS
                try
                    [OPBS_B,~] = getVarNetCDF('OPBS',ncid_B);
                    if sum(isnan(OPBS_B)) ~= length(OPBS_B)
                        isOPBSexist = 'YES';
                    else
                        isOPBSexist = 'NO';
                    end
                catch
                    isOPBSexist= 'NO';
                end
                
                netcdf.close(ncid_B)
                
            else
                isOPBSexist = 'NO';
                isCPHLexist = 'NO';
                isCDOMexist = 'NO';
                
            end
            
            if strcmpi(isAllImagesThere,'ALL_IMAGES') && strcmpi(iscsvFileExist,'YES')
                isVisibleViewer = 'YES';
                isVisiblePortal = 'YES';
            elseif strcmpi(isAllImagesThere,'NONE') && strcmpi(iscsvFileExist,'YES')
                isVisibleViewer = 'NO';
                isVisiblePortal = 'YES';
            elseif strcmpi(isAllImagesThere,'NONE') && strcmpi(iscsvFileExist,'NO')
                isVisibleViewer = 'NO';
                isVisiblePortal = 'YES';
            elseif strcmpi(iscsvFileExist,'NO')
                isVisibleViewer = 'NO';
                isVisiblePortal = 'YES';
            else
                isVisibleViewer = 'YES';
                isVisiblePortal = 'YES';
            end
            
            %% write CSV report
            fidCSV       = fopen(Filename_AUV_reporting, 'a+');
            auvReportCSV = dir(Filename_AUV_reporting);
            if auvReportCSV.bytes == 0
                fprintf(fidCSV, 'campaign_code,campaign_metadata_uuid,dive_code,dive_code_metadata_uuid,openLink,data_on_portal,data_on_auv_viewer,data_folder,geotiff,mesh,multibeam,cdom,cphl,opbs,psal,temp,csv_track_file,dive_report\n');
            end
            
            fprintf(fidCSV, '%s,n.a.,%s,%s,,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n',...
                campaignToProcess,...
                diveToProcess,...
                uuid,...
                isVisiblePortal,...
                isVisibleViewer,...
                [campaignToProcess filesep diveToProcess],...
                isAllImagesThere,...
                ismeshFilesExist,...
                ismultibeamFilesExist,...
                isCDOMexist,...
                isCPHLexist,...
                isOPBSexist,...
                isPSALexist,...
                isTEMPexist,...
                iscsvFileExist,...
                isDiveReportExist);
            
            clear  dataCSV
        end
    end
end
end