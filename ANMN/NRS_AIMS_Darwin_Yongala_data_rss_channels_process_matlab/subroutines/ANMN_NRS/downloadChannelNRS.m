function [alreadyDownloaded,channelInfo,filebroken]=downloadChannelNRS(channelIDToProcess,alreadyDownloaded,channelInfo,levelQC)
%% downloadChannelNRS
% Download a specified channel ID. Here, the date of data to download is
% queried to the AIMS web-service. Then the nc.gz file is downloaded. The
% strcture of the NetCDF file is modified, and some global attributes are
% added. The file is then moved to its respective folder. If a previous
% downloaded file has to be deleted from the DF, it is also done here.
% Finally, the local database is updated each time this function is called.
% We do this in case the program bugs, or there is a sudden problem with
% the VM. But at least none of the previous work done is lost.
%
% This function is the same for both levelQC QAQC and NO QAQC
%
% Inputs: channelInfo        : structure of current RSS feed
%         alreadyDownloaded  : structure of last RSS feed plus last files
%         downloaded
%         channelIDToProcess : double, channelID to download
%         levelQC              : double, 0 or 1
%
% Outputs: channelInfo        : modified structure with new information
%          alreadyDownloaded  : modified structure with new information
%
%
% Example:
%    [channelInfo,alreadyDownloaded]=compareRSSwithPreviousInformationNRS(channelInfo,alreadyDownloaded)
%
% Other m-files required:
% Other files required:
% Subfunctions: none
% MAT-files required: none
%
% See also:
% NRS_processLevel,ListFileDate,DownloadNC,ChangeNetCDF_Structure,
%           NetCDF_getinfo,Move_File,DeleteFile
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 01-Oct-2012
global dataWIP;
global DATE_PROGRAM_LAUNCHED

%% create a list of monthly files to download for each levelQC
if levelQC == 0
    [startDate,stopDate,lastDateToDeleteBoolean]= ListFileDate (alreadyDownloaded.PreviousDateDownloaded_lev0{channelIDToProcess},channelInfo.thruDate{channelIDToProcess});
elseif levelQC == 1
    [startDate,stopDate,lastDateToDeleteBoolean]= ListFileDate (alreadyDownloaded.PreviousDateDownloaded_lev1{channelIDToProcess},channelInfo.thruDate{channelIDToProcess});
end

try
    if levelQC == 0 && isempty(alreadyDownloaded.PreviousDownloadedFile_lev0{channelIDToProcess}) % we test if we have ever downloaded anything for ...
        %a specific channel, in the case that it is available
        %just for one single month. If we don't do that, lastDateToDeleteBoolean=1
        %and the file would be deleted by mistake
        lastDateToDeleteBoolean = 0;
    elseif levelQC == 1 && isempty(alreadyDownloaded.PreviousDownloadedFile_lev1{channelIDToProcess})
        lastDateToDeleteBoolean = 0;
    end
catch %#ok
    lastDateToDeleteBoolean = 0;
end

t = 1;
filebroken = 0;
if ~isempty(startDate) && ~isempty(stopDate)  % startDate and stopDate will be empty if one file has already been downloaded for the current day
    fprintf('%s - channel %d : New data from %s -> %s \n',datestr(now), channelIDToProcess,startDate{1},stopDate{end})
    
    for j=1:size(startDate,2)             % j is the number of files to download for each channel
        [filenameUnrenamed,filepath,~,AIMS_server_online] = DownloadNC(startDate{j},stopDate{j},channelIDToProcess,levelQC,channelInfo.metadata_uuid{channelIDToProcess});
        
        %% test to check server/channel is online
        if AIMS_server_online == 0
            %% we don't record anything,we just go to another channel.
            ChannelIDdown{t} = channelIDToProcess;%#ok
            LogChannelIDdown_DATES = fullfile(dataWIP,strcat('log_ToDo/ChannelID_downDates_',DATE_PROGRAM_LAUNCHED,'.txt'));
            fid_LogChannelIDdown_DATES = fopen(LogChannelIDdown_DATES, 'a+');
            fprintf(fid_LogChannelIDdown_DATES,'%s ; %s ; %s ; %s \n',num2str( ChannelIDdown{t}),num2str(levelQC),startDate{j},stopDate{j});
            fclose(fid_LogChannelIDdown_DATES);
            
            filebroken  = 1;          
            filename    = [];
            filenameDate= [];
            break
        end
        
        if ~isempty(filenameUnrenamed) && ~isempty(filepath)
            filenameUnrenamed = ChangeNetCDF_Structure(filenameUnrenamed,filepath,str2double(channelInfo.long{channelIDToProcess}),str2double(channelInfo.lat{channelIDToProcess}));
        end
        
        
        % if one ZIP files has been downloaded but doesn't have
        % metadata nor data, this is normal. The only file available should be 'NO_DATA_FOUND' This means no data for
        % this time period. The channel might have some data after
        % a period of silence though.
        if ~isempty(filenameUnrenamed) && ~isempty(filepath)
            [yearFile,~,~] = datevec(startDate{j},'yyyy-mm-dd');
            
            [alreadyDownloaded.sensorsLongname{channelIDToProcess},filenameDate,filename] = NetCDF_getinfo (filepath,filenameUnrenamed);
            
            if channelIDToProcess > length(alreadyDownloaded.folderLongnameDepth) % if the channel has never been downloaded before and the channelIDToProcess number is above the size of alreadyDownloaded.folderLongnameDepth
                alreadyDownloaded.folderLongnameDepth{channelIDToProcess} = [];
            end
            
            if isempty(alreadyDownloaded.folderLongnameDepth{channelIDToProcess}) % if the channel has never been downloaded before
                if channelInfo.logical_Depth(channelIDToProcess)
                    alreadyDownloaded.folderLongnameDepth{channelIDToProcess} = strcat(alreadyDownloaded.sensorsLongname{channelIDToProcess},'@',num2str(channelInfo.depth{channelIDToProcess}),'m');
                else
                    alreadyDownloaded.folderLongnameDepth{channelIDToProcess} = alreadyDownloaded.sensorsLongname{channelIDToProcess};
                end
            else % we check that the longname has not changed.would altered the folder name
                if ~strcmp(alreadyDownloaded.sensorsLongname{channelIDToProcess},alreadyDownloaded.folderLongnameDepth{channelIDToProcess}(1:length(alreadyDownloaded.sensorsLongname{channelIDToProcess})))
                    fprintf('%s - ERROR: The NETCDF longname for channel %d has changed. Contact AIMS to understand why !\n',datestr(now),channelIDToProcess)
                end
            end
            
            if ~isNetCDFempty(strcat(filepath,filename))
                Move_File_NRS(channelIDToProcess,channelInfo.siteName{channelIDToProcess},channelInfo.parameterType{channelIDToProcess},alreadyDownloaded.folderLongnameDepth{channelIDToProcess},yearFile,filename,filepath,levelQC,DATE_PROGRAM_LAUNCHED);
                filename_pre = filename; filenameDate_pre = filenameDate; % we keep the last good one
                filebroken=0;
            else
                % if one NetCDF has metadata but no data, we report
                % this channel as broken, go out of the loop. Nothing
                % is therefor modified in PreviousDownload.mat .
                % Everyday, the script will try again.
                
                ChannelIDdown{t}=channelIDToProcess;%#ok
                
                LogChannelIDdown_DATES=fullfile(dataWIP,strcat('log_ToDo/ChannelID_downDates_',DATE_PROGRAM_LAUNCHED,'.txt'));
                fid_LogChannelIDdown_DATES = fopen(LogChannelIDdown_DATES, 'a+');
                fprintf(fid_LogChannelIDdown_DATES,'%s ; %s ; %s ; %s \n',num2str( ChannelIDdown{t}),num2str(levelQC),startDate{j},stopDate{j});
                fclose(fid_LogChannelIDdown_DATES);
                
                Move_brokenFile_NRS(channelIDToProcess,channelInfo.siteName{channelIDToProcess},channelInfo.parameterType{channelIDToProcess},alreadyDownloaded.folderLongnameDepth{channelIDToProcess},yearFile,filename,filepath,levelQC);
                if exist('filename_pre','var') && exist('filenameDate_pre','var')
                    filename=filename_pre;filenameDate=filenameDate_pre;
                else
                    filename=[];filenameDate=[];
                end
                t=t+1;
                filebroken=1;
                %                         break
            end
        elseif strcmpi(filenameUnrenamed,'NO_DATA_FOUND')
            %it means there is no data for this period, this is suppose
            %to be normal.
            filebroken  = 0;
            filename    = [];
            filenameDate= [];
        else
            
            % this means that the zip file is completely empty, the channel has
            % therefor a problem
            % we write a log with channel,startdate,stopdate on each
            % line to redownload next time
            ChannelIDdown{t} = channelIDToProcess;%#ok
            LogChannelIDdown_DATES = fullfile(dataWIP,strcat('log_ToDo/ChannelID_downDates_',DATE_PROGRAM_LAUNCHED,'.txt'));
            fid_LogChannelIDdown_DATES = fopen(LogChannelIDdown_DATES, 'a+');
            fprintf(fid_LogChannelIDdown_DATES,'%s ; %s ; %s ; %s \n',num2str( ChannelIDdown{t}),num2str(levelQC),startDate{j},stopDate{j});
            fclose(fid_LogChannelIDdown_DATES);
            
            
            t           = t+1;
            filebroken  = 1;           
            filename    = [];
            filenameDate= [];
        end
        
        
        
        %lastDateToDeleteBoolean is a boolean,
        if    lastDateToDeleteBoolean==1 && levelQC==0 && ~isempty(filename) && filebroken==0
            File2Delete = alreadyDownloaded.PreviousDownloadedFile_lev0{channelIDToProcess};
            [yearFile2Delete,~,~] = datevec(regexpi(File2Delete,'(*\d*','match','once'),'yyyymmdd');
            
            DeleteFile_NRS(channelIDToProcess,channelInfo.siteName{channelIDToProcess},channelInfo.parameterType{channelIDToProcess},alreadyDownloaded.folderLongnameDepth{channelIDToProcess},yearFile2Delete,File2Delete,levelQC,DATE_PROGRAM_LAUNCHED);
            
            alreadyDownloaded.PreviousDownloadedFile_lev0{channelIDToProcess}=filename;
            alreadyDownloaded.PreviousDateDownloaded_lev0{channelIDToProcess}=strrep(filenameDate,' ','T');
            
            lastDateToDeleteBoolean=0; % we resume lastDateToDeleteBoolean not to delete the last good downloaded file. REALLY IMPORTANT
            
        elseif lastDateToDeleteBoolean==1 && levelQC==1 && ~isempty(filename) && filebroken==0
            
            File2Delete=alreadyDownloaded.PreviousDownloadedFile_lev1{channelIDToProcess};
            %                 [yearFile2Delete,~,~]=datevec(PreviousDateDownloaded_lev1{channelIDToProcess},'yyyy');
            [yearFile2Delete,~,~]=datevec(regexpi(File2Delete,'(*\d*','match','once'),'yyyymmdd');
            DeleteFile_NRS(channelIDToProcess,channelInfo.siteName{channelIDToProcess},channelInfo.parameterType{channelIDToProcess},alreadyDownloaded.folderLongnameDepth{channelIDToProcess},yearFile2Delete,File2Delete,levelQC,DATE_PROGRAM_LAUNCHED);
            
            alreadyDownloaded.PreviousDownloadedFile_lev1{channelIDToProcess}=filename;
            alreadyDownloaded.PreviousDateDownloaded_lev1{channelIDToProcess}=strrep(filenameDate,' ','T');
            
            lastDateToDeleteBoolean=0; % we resume lastDateToDeleteBoolean not to delete the last good downloaded file. REALLY IMPORTANT
            
        elseif lastDateToDeleteBoolean==0 && levelQC==0 && ~isempty(filename) && filebroken==0
            
            alreadyDownloaded.PreviousDownloadedFile_lev0{channelIDToProcess}=filename;
            alreadyDownloaded.PreviousDateDownloaded_lev0{channelIDToProcess}=strrep(filenameDate,' ','T');
            
        elseif lastDateToDeleteBoolean==0 && levelQC==1 && ~isempty(filename) && filebroken==0
            
            alreadyDownloaded.PreviousDownloadedFile_lev1{channelIDToProcess}=filename;
            alreadyDownloaded.PreviousDateDownloaded_lev1{channelIDToProcess}=strrep(filenameDate,' ','T');
        end
        save(fullfile(dataWIP,'PreviousDownload.mat'),'-regexp', 'alreadyDownloaded')
        
    end
else
    if levelQC == 0
        fprintf('%s - channel %d : No new data since %s\n',datestr(now), channelIDToProcess,alreadyDownloaded.PreviousDateDownloaded_lev0{channelIDToProcess})
    elseif levelQC == 1
        fprintf('%s - channel %d : No new data since %s\n',datestr(now), channelIDToProcess,alreadyDownloaded.PreviousDateDownloaded_lev1{channelIDToProcess})
    end
end