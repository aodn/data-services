function [channelInfo]=createInformationListfromChannelsNRS(xmlStructure)
%% createInformationListfromChannelsNRS
% This function reads the xml structure created by xml_parseany, in order
% to sort out all the information found in the RSS feed per channel, such 
% as, lat, lon, siteName, metadata uuid, depth ...
%
% Inputs: xmlStructure        : structure created by xml_parseany
%   
%
% Outputs: channelInfo        : structure
%    
%
% Example: 
%    createInformationListfromChannelsNRS(xmlStructure)
%
% Other m-files required:
% Other files required: 
% Subfunctions: none
% MAT-files required: none
%
% See also: xml_parseany,NRS_processLevel,NRS_Launcher
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 01-Oct-2012

%% initialise MaxChannstrcmpi(filenameUnrenamed,'NO_DATA_FOUND')elValue with b to find the highest value of the ChannelId
[~,b]=size(xmlStructure.channel.item);% some sort of preAllocation       
channelId=cell(b,1);
for i=1:b
    channelId{i}=xmlStructure.channel.item{1,i}.aims_colon_channelId.Text;
end
MaxChannelValue = max(str2double(channelId));

%% preallocation
lat=cell(MaxChannelValue,1);
long=cell(MaxChannelValue,1);
platformName=cell(MaxChannelValue,1);
siteName=cell(MaxChannelValue,1);
parameterType=cell(MaxChannelValue,1);
siteType=cell(MaxChannelValue,1);
title=cell(MaxChannelValue,1);
metadata_uuid=cell(MaxChannelValue,1);
depth=cell(MaxChannelValue,1);
logical_Depth=zeros(MaxChannelValue,1);
sensorType_and_depth_string=cell(MaxChannelValue,1);

%% Create a list of Channel ID sync with the type of the sensor ( pole, buoy or weather station), lat, long, metadata_UUID...
for i=1:b
    k=str2double(channelId{i});
    
    lat{k}=xmlStructure.channel.item{1,i}.geo_colon_lat.Text;
    long{k}=xmlStructure.channel.item{1,i}.geo_colon_long.Text;
    metadata_uuid{k}=xmlStructure.channel.item{1,i}.aims_colon_metadataLink.Text;
    platformName{k}=xmlStructure.channel.item{1,i}.aims_colon_platformName.Text;
    parameterType{k}=xmlStructure.channel.item{1,i}.aims_colon_parameterType.Text;
    
    if ~isempty(strfind( platformName{k},'Weather Station Platform'))
        indexStart=strfind( platformName{k},'Weather Station Platform');
        siteType{k}=platformName{k}(indexStart:end);
    elseif  ~isempty(strfind( platformName{k},'Buoy'))
        indexStart=strfind( platformName{k},'Buoy');
        siteType{k}=platformName{k}(indexStart:end);
    end
    
    siteName{k}=xmlStructure.channel.item{1,i}.aims_colon_siteName.Text;
    title{k}=xmlStructure.channel.item{1,i}.title.Text;
    
    %     if ~isempty(strfind( title{k},'@-'))
    %         indexStartbis=strfind( title{k},'@-')+1;
    %     else indexStartbis=strfind( title{k},'@');
    %     end
    
    %     indexstop=strfind( title{k}(indexStartbis+1:end),'m')-1;
    %     sensors{k}=title{k}(1:indexStartbis-1);
    %     sensors{k}=strrep(sensors{k}, ' ', '_'); %remove blank character
    
    if ~isempty(strfind( title{k},'@'))
        logical_Depth(k)=1;
        indexStartbis=strfind( title{k},'@');
        indexstop=strfind( title{k}(indexStartbis+1:end),'m')-1;
        depth{k}=strcat(title{k}(indexStartbis+1:indexStartbis+indexstop(1)));
    else
        logical_Depth(k)=0;
        depth{k}=num2str(0);
    end
    
    parameterType{k}=strrep(parameterType{k}, ' ', '_'); %remove blank character
    
    if logical_Depth(k)
        sensorType_and_depth_string{k}=strcat(parameterType{k},'@',num2str(depth{k}),'m');
    else
        sensorType_and_depth_string{k}=parameterType{k};
    end
    
    siteType{k}=strrep(siteType{k}, ' ', '_'); %remove blank character
    siteName{k}=strrep(siteName{k}, ' ', '_'); %remove blank character
    
    clear indexstop
end

channelInfo=struct;
channelInfo.lat=lat;
channelInfo.long=long;
channelInfo.platformName=platformName;
channelInfo.siteName=siteName;
channelInfo.parameterType=parameterType;
channelInfo.siteType=siteType;
channelInfo.title=title;
channelInfo.metadata_uuid=metadata_uuid;
channelInfo.depth=depth;
channelInfo.logical_Depth=logical_Depth;
channelInfo.sensorType_and_depth_string=sensorType_and_depth_string;
channelInfo.channelId=channelId;

end