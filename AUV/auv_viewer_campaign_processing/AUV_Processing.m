function AUV_Processing()
% AUV_Processing process a list of campaign to create
% 1) CSV outputs for each campaign. The info found in the CSV
% are used by a talend harvester to populate the auv_viewer website
% database
% 2) thumbnails of individual TIFF images
%
% see https://github.com/aodn/harvesters/tree/master/workspace/AUV_VIEWER_TRACKS
%
% Inputs: see confix.txt
%
% Outputs:
%
% Author: Laurent Besnard <laurent.besnard@utas,edu,au>
% Oct 2010; Last revision: 31-Oct-2014
%
%
format long

%%  script location
WhereAreScripts = what;
scriptPath = WhereAreScripts.path;
addpath(genpath(scriptPath));



releasedCampaignPath          = getenv('released_campaign_path');
processedDataOutputPath       = getenv('processed_data_output_path');
mkpath(processedDataOutputPath)

%% These are the names of the campaign folder
campaignName = textscan(getenv('campaignName'),'%s','delimiter',',');
campaignName = campaignName{1};
campaignName = campaignName(~cellfun('isempty',campaignName));

%% Log File
diary (strcat(processedDataOutputPath,filesep,getenv('logfile_name')));


%%  Proccess all the campaings
for iCampaign = 1:length(campaignName)
    fprintf('%s - Campaign: "%s" currently processed\n',datestr(now),char(campaignName(iCampaign)))
    campaignToProcess = cell2mat(campaignName(iCampaign));
    mkpath(strcat(processedDataOutputPath,filesep,campaignToProcess));

    Dives = dir(strcat(releasedCampaignPath,filesep,campaignToProcess,filesep,'r*'));
    nDives = length(Dives);

%         % file output used by the talend harvester
%         CSV_TABLE_METADATA_file = strcat(processedDataOutputPath,filesep,campaignToProcess,filesep,'TABLE_METADATA_', campaignToProcess,'.csv');
%         if exist(CSV_TABLE_METADATA_file,'file') == 2
%             delete(CSV_TABLE_METADATA_file)
%         end


    %%  Proccess all the dives of the iCampaign
    for tDive = 1:nDives

        diveToProcess = char(Dives(tDive,1).name);
        fprintf('%s - Dive: "%s" currently processed\n',datestr(now),diveToProcess)

%             CSV_TABLE_DATA_file = strcat(processedDataOutputPath,filesep,campaignToProcess,filesep,'TABLE_DATA_', campaignToProcess,'_',diveToProcess,'.csv');
%             if exist(CSV_TABLE_DATA_file,'file') == 2
%                 delete(CSV_TABLE_DATA_file)
%             end
        %% create uuids used to populated Metadata Records per Dive
        createUUID(campaignToProcess,diveToProcess)

        %% get information of each images

        % we check that no images have been added to the tif
        % directory for each dive. otherwise we re-create from scratch
        % sample_data_file. We do this in case we have to reprocess
        % a dive campaign, but no images has been added, in order
        % to save time in the reprocessing.
        sample_data_file = strcat(processedDataOutputPath,filesep,campaignToProcess,filesep,'sample_data_',diveToProcess,'.mat');
        if exist(sample_data_file,'file') == 2
            load (sample_data_file, '-mat')

            TIFF_dir = dir([releasedCampaignPath filesep campaignToProcess filesep diveToProcess filesep  'i2*gtif']);
            tiffImagesFullPath = [releasedCampaignPath filesep campaignToProcess filesep diveToProcess filesep TIFF_dir.name];

            list_images = dir([tiffImagesFullPath filesep '*LC16.tif']);
            if length(list_images) ~= length(sample_data) % if the size is different we reprocess
                [sample_data, errorID ] = getImageinfoGDAL2(releasedCampaignPath,campaignToProcess,diveToProcess); % this function needs gdalinfo to be installed on a unix system
                save(sample_data_file,'sample_data','errorID')
            end
        else
            [sample_data, errorID ] = getImageinfoGDAL2(releasedCampaignPath,campaignToProcess,diveToProcess); % this function needs gdalinfo to be installed on a unix system
            save(sample_data_file,'sample_data','errorID')
        end

        if ~isempty(errorID)
            fprintf('%s - WARNING: The following files had errors\n',datestr(now))
            disp(errorID)
        end

        nImagesInSampleData = length(sample_data); % we do this before calling matchData :in case the csv is corrupted, the size of sample_data would be empty.
        %% match images time with parameters measured (pitch roll T P S ...)
        try
            [metadata, sample_data] = matchData(sample_data,campaignToProcess,diveToProcess);
        catch
            metadata    = struct;
            sample_data = struct;
            fprintf('%s - ERROR - Dive %s cannot be processed\n',datestr(now),diveToProcess)
        end

        if ~isempty(fieldnames( sample_data))
            %% CREATE CSV outputs used by the talend harvester to populate
            createCSV_talend(metadata, sample_data);


            %% check and write the name of the corrupted images, to download them later
            if ~isempty(errorID)
                Filename_corruptedFiles = strcat(processedDataOutputPath,filesep,'ReadME_corruptedFiles.txt');
                fid_Filename_corruptedFiles = fopen(Filename_corruptedFiles, 'a+');
                fprintf(fid_Filename_corruptedFiles,'**Campaing-Dive: %s \n',strcat(campaignToProcess,filesep,diveToProcess));
                for u=1:length(errorID)
                    fprintf(fid_Filename_corruptedFiles,'Corrupted file: %s \n',errorID{u});
                end
                fclose(fid_Filename_corruptedFiles);
            end
        else
            fprintf('%s - WARNING: The dive "%s" could not be processed properly. Some folders/files were missing\n',datestr(now),diveToProcess)
        end


        munlock matchData;
        clear -regexp metadata sample_data
        close all
        [~, ~] = system('sync','-echo');
        [~, ~] = system('free -m');


        %% create the thumbnails of the images\

        %the temporary path where new thumbnails are created before being moved to the prod path
        auvViewerThumbnails_tmpDivePath     = [processedDataOutputPath filesep campaignToProcess filesep diveToProcess filesep 'i2jpg'];

        %the prod path of thumbnails used by the auv viewer
        auvViewerThumbnails_prodDivePath    = [getenv('auvViewerThumbnails.path') filesep campaignToProcess filesep diveToProcess filesep 'i2jpg'];

        if exist(auvViewerThumbnails_tmpDivePath,'dir') == 7
            list_imagesAlreadyProcessed = dir([auvViewerThumbnails_prodDivePath filesep '*LC16.jpg']);

            if length(list_imagesAlreadyProcessed) ~= nImagesInSampleData
                % then we convert all the missing images into thumbnails
                ConvertImages(campaignToProcess,diveToProcess)
            end
        else
            ConvertImages(campaignToProcess,diveToProcess)
        end

    end % end of dive process

end % end of campaign process

try
    AUV_Reporting
catch Err
   fprintf('%s - WARNING: %s\n',datestr(now),Err.message)
end

