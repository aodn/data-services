function AUV_Processing_FAST()
% AUV_Processing_FAST does the same job as AUV_Processing but assuming all
% thumbnails have already been created, and no images was added to the main
% data dir. This way, there is no listing of images to do which can be
% really time consuming. A campaign can be re-processed quickly if there is
% a new track*.csv new netcdf files
%

%%  script location
WhereAreScripts = what;
scriptPath = WhereAreScripts.path;
addpath(genpath(scriptPath));

configFile = dir('config.txt');

releasedCampaignPath          = readConfig('releasedCampaign.path', configFile.name,'=');
processedDataOutputPath       = readConfig('processedDataOutput.path', configFile.name,'=');
mkpath(processedDataOutputPath)

%% These are the names of the campaign folder
campaignName = textscan(readConfig('campaignName', configFile.name,'='),'%s','delimiter',',');
campaignName = campaignName{1};
campaignName = campaignName(~cellfun('isempty',campaignName));

%% Log File
diary (strcat(processedDataOutputPath,filesep,readConfig('logFile.name', configFile.name,'=')));


%%  Proccess all the campaings
for iCampaign = 1:length(campaignName)
    fprintf('%s - Campaign: "%s" currently processed\n',datestr(now),char(campaignName(iCampaign)))
    campaignToProcess = cell2mat(campaignName(iCampaign));
    mkpath(strcat(processedDataOutputPath,filesep,campaignToProcess));
    
    Dives = dir(strcat(releasedCampaignPath,filesep,campaignToProcess,filesep,'r*'));
    nDives = length(Dives);
    
    
    %%  Proccess all the dives of the iCampaign
    for tDive = 1:nDives        
        diveToProcess = char(Dives(tDive,1).name);
        fprintf('%s - Dive: "%s" currently processed\n',datestr(now),diveToProcess)
        
        
        %% create uuids used to populated Metadata Records per Dive
        createUUID(campaignToProcess,diveToProcess)
        
        %% get information of each images
        sample_data_file = strcat(processedDataOutputPath,filesep,campaignToProcess,filesep,'sample_data_',diveToProcess,'.mat');
        if exist(sample_data_file,'file') == 2
            load (sample_data_file, '-mat')
            
        else
            fprintf('%s - WARNING: Cannot run AUV_Processing_FAST on this dive. Never been processed before. Please use AUV_Processing first\n',datestr(now))
        end
        
        %% match images time with parameters measured (pitch roll T P S ...)
        try
            [metadata, sample_data] = matchData(sample_data,campaignToProcess,diveToProcess);
        catch
            metadata    = struct;
            sample_data = struct;
            fprintf('%s - ERROR - Dive %s cannot be processed\n',datestr(now),diveToProcess)
        end
        
        if ~isempty(fieldnames(sample_data))
            %% CREATE CSV outputs used by the talend harvester to populate
            createCSV_talend(metadata, sample_data);
        else
            fprintf('%s - WARNING: The dive "%s" could not be processed properly. Some folders/files were missing\n',datestr(now),diveToProcess)
        end
        
        
        munlock matchData;
        clear -regexp metadata sample_data
        close all
        [~, ~] = system('sync','-echo');
        [~, ~] = system('free -m');
                
    end % end of dive process
    
end % end of campaign process


