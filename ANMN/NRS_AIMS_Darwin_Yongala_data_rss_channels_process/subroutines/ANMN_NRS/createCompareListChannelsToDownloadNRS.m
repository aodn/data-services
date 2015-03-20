function [channelInfo,alreadyDownloaded]=createCompareListChannelsToDownloadNRS(channelInfo,xmlStructure,level)
%% createCompareListChannelsToDownloadNRS
% This function initialises the local database 'PreviousDownload.mat' to
% know what is the last date of data downloaded for each channel. Then
% channelInfo which has been created previously from the RSS feed, is
% updated, with information such as 'fromDate': i.e. first date of data, which
% we change afterwards to last date of data we have downloaded.
%
% This function is the same for both level QAQC and NO QAQC
%
% Inputs: channelInfo   : structure of current RSS feed
%         xmlStructure  : structure of last RSS feed
%         level         : double 0 or 1 ( RAW, QAQC)
%
% Outputs: channelInfo        : modified structure with new information
%          alreadyDownloaded  : structure w
%
%
% Example:
%    [channelInfo,alreadyDownloaded]=createCompareListChannelsToDownloadNRS(channelInfo,xmlStructure,level)
%
% Other m-files required:
% Other files required:
% Subfunctions: none
% MAT-files required: none
%
% See also: NRS_processLevel,compareRSSwithPreviousInformationNRS
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 01-Oct-2012

dataWIP          = getenv('data_wip_path');

[~,b]=size(xmlStructure.channel.item);% some sort of preAllocation
channelId=cell(b,1);
for i=1:b
    channelId{i}=xmlStructure.channel.item{1,i}.aims_colon_channelId.Text;
end

MaxChannelValue = max(str2double(channelInfo.channelId));

fromDate=cell(MaxChannelValue,1);
thruDate=cell(MaxChannelValue,1);
%% Load the last downloaded date for each channel if available
if exist(fullfile(dataWIP,'PreviousDownload.mat'),'file')
    load (fullfile(dataWIP,'PreviousDownload.mat'))
else
    alreadyDownloaded.PreviousDateDownloaded_lev0=cell(MaxChannelValue,1);
    alreadyDownloaded.PreviousDateDownloaded_lev1=cell(MaxChannelValue,1);
    alreadyDownloaded.PreviousDownloadedFile_lev0=cell(MaxChannelValue,1);
    alreadyDownloaded.PreviousDownloadedFile_lev1=cell(MaxChannelValue,1);
    alreadyDownloaded.sensorsLongname=cell(MaxChannelValue,1);
    alreadyDownloaded.folderLongnameDepth=cell(MaxChannelValue,1);
    alreadyDownloaded.channelStringInformation=cell(MaxChannelValue,1);
end
nChannel=length(channelInfo.channelId);

%% Create a list of dates to download for each channel
for i=1:nChannel
    k=str2double(channelInfo.channelId{i});
    [ate]=find(ismember(str2double(channelId), k)==1);

    %in case one channel is subdivised when a channel is off for
    %maintenance
    if size(ate,1)>1
        fprintf('%s - ERROR: RSS feed is corrupted, more than one entry per channel\n',datestr(now))
        break

    elseif isempty(ate)
        continue

    else
        fromDate{k}=xmlStructure.channel.item{1,ate}.aims_colon_fromDate.Text;
        thruDate{k}=xmlStructure.channel.item{1,ate}.aims_colon_thruDate.Text;
    end


   switch level
        case 0
            try
                if isempty(alreadyDownloaded.PreviousDateDownloaded_lev0{k})
                    alreadyDownloaded.PreviousDateDownloaded_lev0{k}=fromDate{k};
                end
            catch %#ok
                alreadyDownloaded.PreviousDateDownloaded_lev0{k}=fromDate{k};
                alreadyDownloaded.PreviousDownloadedFile_lev0{k}=[];
            end


        case 1
            try
                if isempty(alreadyDownloaded.PreviousDateDownloaded_lev1{k})
                    alreadyDownloaded.PreviousDateDownloaded_lev1{k}=fromDate{k};
                end
            catch %#ok
                alreadyDownloaded.PreviousDateDownloaded_lev1{k}=fromDate{k};
                alreadyDownloaded.PreviousDownloadedFile_lev1{k}=[];
            end
    end

    clear ate fromDate_bis thruDate_bis
end

channelInfo.fromDate=fromDate;
channelInfo.thruDate=thruDate;

end

