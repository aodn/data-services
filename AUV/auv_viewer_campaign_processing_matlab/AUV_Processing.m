function AUV_Processing()
%AUV_Processing process entirely a campaign or list of campaing. This function
%is more a script than a function and the user has to change the "inputs" to make
%it work for himself.
%It creates two main SQL script files in $DATA_OUTPUT_FOLDER to load into postgreSQL. They create
%the necessary tables. 2 other SQL files are created and stored in
%$DATA_OUTPUT_FOLDER / $Campaign with the values added to the tables. Then a last
%procedure is launched to create the images thumbnails stored in
%$DATA_OUTPUT_FOLDER / $Campaign / $Dive / i2jpg .
% Inputs:
%   DATA_OUTPUT_FOLDER       - str pointing to the folder where the user wants to
%                       save the SQL file.
%   RELEASED_CAMPAIGN_FOLDER        - str pointing to the main AUV folder address ( could be
%                       local or on the DF through a mount.davfs
%   campaignName     - a list of campaign names to process
%
% Outputs:
%
% Author: Laurent Besnard <laurent.besnard@utas,edu,au>
% Oct 2010; Last revision: 31-Oct-2012
%
%
%setenv LD_LIBRARY_PATH $MATLAB/bin/bin/ksh
% setenv('ksh','/bin/ksh');
% getenv('ksh');
format long

%%  script location
WhereAreScripts=what;
AUV_MATLAB_CODE_FOLDER=WhereAreScripts.path;
addpath(genpath(AUV_MATLAB_CODE_FOLDER));

configFile=dir('config*.txt');

for cc=1:length(configFile)
    RELEASED_CAMPAIGN_FOLDER        =readConfig('releasedCampaign.path', configFile(cc).name,'=');
    DATA_OUTPUT_FOLDER              =readConfig('proccessedDataOutput.path', configFile(cc).name,'=');
    mkpath(DATA_OUTPUT_FOLDER)
    
    %% These are the names of the campaign folder
    campaignName=textscan(readConfig('campaignName', configFile(cc).name,'='),'%s','delimiter',',');
    campaignName=campaignName{1};
    campaignName=campaignName(~cellfun('isempty',campaignName));
    
    %% Log File
    diary (strcat(DATA_OUTPUT_FOLDER,filesep,readConfig('logFile.name', configFile(cc).name,'=')));
    
    
    %%  Proccess all the campaings
    for k=1:length(campaignName)
        fprintf('%s - Campaign: "%s" currently proccessed\n',datestr(now),char(campaignName(k)))
        campaignToProcess=cell2mat(campaignName(k));
        mkpath(strcat(DATA_OUTPUT_FOLDER,filesep,campaignToProcess));
        
        Dives=dir(strcat(RELEASED_CAMPAIGN_FOLDER,filesep,campaignToProcess,filesep,'r*'));
        nDives=length(Dives);
        
        % if this is the second time AUV_processing is running for a same
        % campaign, it is necessary to delete the SQL files, not to have
        % duplicates INSERTS
        DB_TABLE_DATA_file = strcat(DATA_OUTPUT_FOLDER,filesep,campaignToProcess,filesep,'DB_TABLE_DATA_', campaignToProcess,'.sql');
        DB_TABLE_METADATA_file = strcat(DATA_OUTPUT_FOLDER,filesep,campaignToProcess,filesep,'DB_TABLE_METADATA_', campaignToProcess,'.sql');
        
        if exist(DB_TABLE_DATA_file,'file')
            delete(DB_TABLE_DATA_file)
        end
        
        if exist(DB_TABLE_METADATA_file,'file')
            delete(DB_TABLE_METADATA_file)
        end
        
        %%  Proccess all the dives of the k campaing
        for t=1:nDives
            
            diveToProcess=char(Dives(t,1).name);
            fprintf('%s - Dive: "%s" currently proccessed\n',datestr(now),diveToProcess)
            
            %% create uuids
            createUUID(campaignToProcess,diveToProcess)
            
            %% get information of each images
            % [sample_data, errorID]=getImageinfo(RELEASED_CAMPAIGN_FOLDER,campaignToProcess,diveToProcess);% this version needs the matlab mapping toolbox to work
            % [sample_data, errorID ]=getImageinfoGDAL(RELEASED_CAMPAIGN_FOLDER,campaignToProcess,diveToProcess); % this function needs gdalinfo to be installed on a unix system
            
            % we check that no images have been added to the tif
            % directory for each dive. otherwise we re-create from scratch
            % sample_data_file. We do this in case we have to reprocess
            % a dive campaign, but no images has been added, in order
            % to save time in the reprocessing.
            sample_data_file = strcat(DATA_OUTPUT_FOLDER,filesep,campaignToProcess,filesep,'sample_data_',diveToProcess,'.mat');
            if exist(sample_data_file,'file') == 2
                load (sample_data_file, '-mat')
                
                TIFF_dir=dir([RELEASED_CAMPAIGN_FOLDER filesep campaignToProcess filesep diveToProcess filesep  'i2*gtif']);
                tiffPath=[RELEASED_CAMPAIGN_FOLDER filesep campaignToProcess filesep diveToProcess filesep TIFF_dir.name];
                
                list_images=dir([tiffPath filesep '*LC16.tif']);
                if length(list_images) ~= length(sample_data) % if the size is different we reprocess
                    [sample_data, errorID ]=getImageinfoGDAL2(RELEASED_CAMPAIGN_FOLDER,campaignToProcess,diveToProcess); % this function needs gdalinfo to be installed on a unix system
                    save(sample_data_file,'sample_data','errorID')
                end
            else
                [sample_data, errorID ]=getImageinfoGDAL2(RELEASED_CAMPAIGN_FOLDER,campaignToProcess,diveToProcess); % this function needs gdalinfo to be installed on a unix system
                save(sample_data_file,'sample_data','errorID')
            end
            
            if ~isempty(errorID)
                fprintf('%s - WARNING: The following files had errors\n',datestr(now))
                disp(errorID)
            end
            
            nImagesInSampleData = length(sample_data); % we do this before calling matchData :in case the csv is corrupted, the size of sample_data would be empty.
            %% match images time with parameters measured (pitch roll T P S ...)
            try
                [metadata, sample_data]=matchData(sample_data,RELEASED_CAMPAIGN_FOLDER,campaignToProcess,diveToProcess);
            catch
                metadata=struct;
                sample_data=struct;
                fprintf('%s - ERROR - Dive %s cannot be processed\n',datestr(now),diveToProcess)
            end
            
            if ~isempty(fieldnames( sample_data))
                %% create the sql scripts to load in the postgis db
                CreateSQLTable(DATA_OUTPUT_FOLDER);
                MakeSQLfile(metadata, sample_data);
                
                %% check and write the name of the corrupted images, to download them later
                if ~isempty(errorID)
                    Filename_corruptedFiles=strcat(DATA_OUTPUT_FOLDER,filesep,'ReadME_corruptedFiles.txt');
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
            %         pack;
            [~, ~] = system('sync','-echo');
            [~, ~] = system('free -m');
            
            
            %% create the thumbnails of the images
            thumbnailFolder = [DATA_OUTPUT_FOLDER filesep campaignToProcess filesep diveToProcess filesep 'i2jpg'];
            if exist(thumbnailFolder,'dir') == 7
                list_imagesAlreadyProcessed = dir([thumbnailFolder filesep '*LC16.jpg']);
                
                if length(list_imagesAlreadyProcessed) ~= nImagesInSampleData
                    % then we convert all the images into thumbnails
                    ConvertImages(RELEASED_CAMPAIGN_FOLDER,DATA_OUTPUT_FOLDER,campaignToProcess,diveToProcess)
                end
            else
                ConvertImages(RELEASED_CAMPAIGN_FOLDER,DATA_OUTPUT_FOLDER,campaignToProcess,diveToProcess)
            end
            
        end % end of dive process
        
    end % end of campaign process
end