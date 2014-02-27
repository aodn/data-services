function [channelInfo,alreadyDownloaded]=compareRSSwithPreviousInformationFAIMMS(channelInfo,alreadyDownloaded)
%% compareRSSwithPreviousInformationFAIMMS
% AIMS has a tendency to modify easily the RSS feed and some informations used:
% -to populate the NETCDF files (such as the metadata_uuid);
% -to create the folder structure (such as the depth and sensor type of each sensor).
% In order to avoid the creation of many different folders for the same
% channel when this happens, we want to compare for each of them what
% has been modified. This is the goal of this function. If one of
% these important information is different from the last launch, we decide
% to delete the entire copy from the datafabric and all information
% concerning this channel found in 'PreviousDownload.mat'. The channels to
% remove are written in a text file 'ChannelID_2removeCompletely_...' which
% will be later used by DataFabricFileManagement.m
% This function is the same for both level QAQC and NO QAQC
%
% Inputs: channelInfo        : structure of current RSS feed
%         alreadyDownloaded  : structure of last RSS feed plus last files
%         downloaded
%
%
% Outputs: channelInfo        : modified structure with new information
%          alreadyDownloaded  : modified structure with new information
%
%
% Example:
%    [channelInfo,alreadyDownloaded]=compareRSSwithPreviousInformationFAIMMS(channelInfo,alreadyDownloaded)
%
% Other m-files required:
% Other files required:
% Subfunctions: none
% MAT-files required: none
%
% See also: FAIMMS_processLevel,DataFabricFileManagement
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 01-Oct-2012
global FAIMMS_DownloadFolder;

MaxChannelValue = max(str2double(channelInfo.channelId));
nChannel=length(channelInfo.channelId);

%% this part of code is here to see if any RSS inputs has changed that
%% would modify the NETCDF and the folder structure. In case it has
%% changed, we redownload the channel, and remove all previous files
%% first time creation of alreadyDownloaded.channelStringInformation
if ~exist(fullfile(FAIMMS_DownloadFolder,'PreviousDownload.mat'),'file')
    for i=1:nChannel
        k=str2double(channelInfo.channelId{i});
        alreadyDownloaded.channelStringInformation{k}=strcat(channelInfo.siteName{k},filesep,channelInfo.siteType{k},filesep,channelInfo.parameterType{k},filesep,channelInfo.sensorType_and_depth_string{k},'_channel_',num2str(k));
    end
else
    for i=1:nChannel
        k=str2double(channelInfo.channelId{i});
        if k > length(alreadyDownloaded.channelStringInformation)
            alreadyDownloaded.channelStringInformation{k}=strcat(channelInfo.siteName{k},filesep,channelInfo.siteType{k},filesep,channelInfo.parameterType{k},filesep,channelInfo.sensorType_and_depth_string{k},'_channel_',num2str(k));
        elseif  isempty(alreadyDownloaded.channelStringInformation{k}) %means it's the first time this channel is downloaded and for example, the noQAQC is not downloaded but the QAQC is
            alreadyDownloaded.channelStringInformation{k}=strcat(channelInfo.siteName{k},filesep,channelInfo.siteType{k},filesep,channelInfo.parameterType{k},filesep,channelInfo.sensorType_and_depth_string{k},'_channel_',num2str(k));
        end
    end
end

%% we build the folder name according to today's RSS feed,to be sure that
%% nothing has changed
channelStringTodayRSSInformation=cell(MaxChannelValue,1);
for i=1:nChannel
    k=str2double(channelInfo.channelId{i});
    channelStringTodayRSSInformation{k}=strcat(channelInfo.siteName{k},filesep,channelInfo.siteType{k},filesep,channelInfo.parameterType{k},filesep,channelInfo.sensorType_and_depth_string{k},'_channel_',num2str(k));
end

%% because we use the same variable for both level which can have a
%% different number of channels. A new channel can be added as well in the RSS
%% feed
if length(channelStringTodayRSSInformation)>length(alreadyDownloaded.channelStringInformation) %%ie the code has been started first by downloading level 1,because there are less level 1 channels than level 0 because not all channels have their QAQC configured
    A=cell(length(channelStringTodayRSSInformation),1);
    A(1:length(alreadyDownloaded.channelStringInformation))=alreadyDownloaded.channelStringInformation;
    IdxDifferentFolders=strcmp(A,channelStringTodayRSSInformation);
    
    clear A
elseif length(alreadyDownloaded.channelStringInformation)  > length(channelStringTodayRSSInformation)  %%ie the code has been started first by downloading level 0
    A=cell(length(alreadyDownloaded.channelStringInformation),1);
    A(1:length(channelStringTodayRSSInformation))=channelStringTodayRSSInformation;
    
    IdxDifferentFolders=strcmp(A,alreadyDownloaded.channelStringInformation);
    clear A
elseif length(channelStringTodayRSSInformation)==length(alreadyDownloaded.channelStringInformation)
    IdxDifferentFolders=strcmp(channelStringTodayRSSInformation,alreadyDownloaded.channelStringInformation);
end

%% but if something has changed, we delete all the previous information,
%% and redownload the channel from scratch. We have to delete files from
%% the DataFabric as well, and check it's online
if exist(fullfile(FAIMMS_DownloadFolder,strcat('log_ToDo/')),'dir')==0
    mkdir(fullfile(FAIMMS_DownloadFolder,strcat('log_ToDo/')));
end

LogChannelID_2_remove_completely=fullfile(FAIMMS_DownloadFolder,strcat('log_ToDo/ChannelID_2removeCompletely_',datestr(now,'yyyymmdd_HHMM'),'.txt'));
fid_LogChannelID_2_remove_completely = fopen(LogChannelID_2_remove_completely, 'a+');

maxToUse=min(length(alreadyDownloaded.channelStringInformation),length(IdxDifferentFolders));
maxToUse=min(maxToUse,length(channelInfo.fromDate));
for k=1:maxToUse
    if IdxDifferentFolders(k)==0 && ~isempty(channelStringTodayRSSInformation{k}) %% condition to remove channel,because depending of the level,maybe a channel won't exist, and channelStringTodayRSSInformation will be empty
        alreadyDownloaded.PreviousDateDownloaded_lev0{k}=channelInfo.fromDate{k};
        alreadyDownloaded.PreviousDateDownloaded_lev1{k}=channelInfo.fromDate{k};
        alreadyDownloaded.PreviousDownloadedFile_lev0{k}=[];
        alreadyDownloaded.PreviousDownloadedFile_lev1{k}=[];
        
        % warning alreadyDownloaded.channelStringInformation IS NOT
        % the folder name, only informations.
        
        indexEndFirstPartFolderName=regexp(alreadyDownloaded.channelStringInformation{k},filesep);
        fprintf(fid_LogChannelID_2_remove_completely,'%s \n',strcat(alreadyDownloaded.channelStringInformation{k}(1:indexEndFirstPartFolderName(end)),alreadyDownloaded.folderLongnameDepth{k},'_channel_',num2str(k)));
        
        alreadyDownloaded.channelStringInformation{k}=channelStringTodayRSSInformation{k}; % rewrite alreadyDownloaded.channelStringInformation with good values for both level 0 & 1
        alreadyDownloaded.folderLongnameDepth{k}=[]; % we erase this value. this will be modified in downloadChannelFAIMMS.m
    end
end
fclose(fid_LogChannelID_2_remove_completely);

%% if the file is empty, means no channel to remove, we delete the logfile
LogFile=dir(LogChannelID_2_remove_completely);
if LogFile.bytes==0
    delete(LogChannelID_2_remove_completely,'file')
end
end