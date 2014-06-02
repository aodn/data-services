function ChannelIDdown=SOOP(level)
% SOOP needs an http access to download the xml RSS feed
% for the SOOP data. This function needs as well writting access to the
% folder 'SOOP_DownloadFolder' in which everything is stored.
% The RSS feed is sustain enough to automate fully the download of data
% from AIMS server to IMOS data server even with new channels, platforms or
% sites.
%
% This function has to be run once a day. It checks the last date available of
% data to download for each channel, downloads the new NetCDF file(s) to the
% folder 'SOOP_DownloadFolder'/NEW_Downloads/, then move them into
% 'SOOP_DownloadFolder'/sorted/ . The last downloaded date for each
% channel is stored in the file 'SOOP_DownloadFolder'/PreviousDownload.mat
% For each month, if one more day of data is available, all the data since
% the 1st of the current month is downloaded, and the previous file is
% automaticaly deteled from 'SOOP_DownloadFolder'/Sorted ... but not from
% the opendap server. This is why a text file called
% 'SOOP_DownloadFolder'/file2delete.txt is created. On each line is written
% the last file to delete on opendap.
%
% example : One\ Tree\ Island/Sensor\ Pole1/temperature/Water\
% Temperature@0.0m\ -channel_2/2010/level0_id2_2010-10-01T00-00-00Z_until_2010-10-08T09-42-37Z.nc
%
% Once a script or the user has deleted the NetCDF file(s), file2delete.txt can be
% deleted as well.
%
% Inputs:
%   level                 - integer 0 = No QAQC ; 1 = QAQC
%   XML                   - https address of the RSS fee
%   SOOP_DownloadFolder   - Folder where data will be daily downloaded
%
%
% Outputs in 'SOOP_DownloadFolder'/ :
%   DB_TABLE_sites.sql         - PSQL scripts for all different sites
%   DB_TABLE_platforms         - PSQL scripts for all different platforms
%   DB_TABLE_parameters.sql    - PSQL scripts for all different parameters
%   file2delete.txt            - Text file which fives the file location to
%                                delete on opendap ( or a remote folder
%                                which is not synchronised)
%   PreviousDownload.mat       - Matlab matrix in which the last downloaded
%                                date of each channel is stored. if the
%                                date doesn't exist, the script will
%                                download all the data since the launching
%                                date of the channel.
%   /sorted/...                - NetCDF files sorted by
%                               site/platform/parameter/sensor_depth/year
%
% Author: Laurent Besnard <laurent.besnard@utas,edu,au>
%
%
% Copyright (c) 2010, eMarine Information Infrastructure (eMII) and Integrated
% Marine Observing System (IMOS).
% All rights reserved.
%
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are met:
%
%     * Redistributions of source code must retain the above copyright notice,
%       this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright
%       notice, this list of conditions and the following disclaimer in the
%       documentation and/or other materials provided with the distribution.
%     * Neither the name of the eMII/IMOS nor the names of its contributors
%       may be used to endorse or promote products derived from this software
%       without specific prior written permission.
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.
%
warning('off','all')
global SOOP_DownloadFolder;
global DataFabricFolder;

DATE_PROGRAM_LAUNCHED=datestr(now,'yyyymmdd');

if exist(SOOP_DownloadFolder,'dir') == 0
    mkdir(SOOP_DownloadFolder);
end

%% XML link and SAVING folder
XML=strcat('http://data.aims.gov.au/gbroosdata/services/rss/netcdf/level',num2str(level),'/100') ;     %XML file downloaded from the SOOP RSS feed
filenameXML=fullfile(SOOP_DownloadFolder,strcat('SOOP_',num2str(level),'.xml'));

try
        urlwrite(XML, filenameXML);
catch
        fprintf('%s - ERROR: XML file is not accessible. If problem persists,contact AIMS \n',datestr(now))
        ChannelIDdown=[];
        return;
end

V = xml_parseany(fileread(filenameXML));                                    %Create the structure from the XML file
delete(filenameXML);
[~,b]=size(V.channel{1,1}.item);                                            %Number of channels available

%% initialise MaxChannelValue with b to find the highest value of the ChannelId
channelId=cell(b,1);
MaxChannelValue=b;
for i=1:b
    channelId{i}=V.channel{1,1}.item{1,i}.channelId{1,1}.CONTENT;
    if MaxChannelValue < str2double(channelId{i});
        MaxChannelValue = str2double(channelId{i});
    end
end

%% Load the last downloaded date for each channel if available
if exist(fullfile(SOOP_DownloadFolder,'PreviousDownload.mat'),'file')
    load (fullfile(SOOP_DownloadFolder,'PreviousDownload.mat'))
else
    PreviousDateDownloaded_lev0=cell(MaxChannelValue,1);
    PreviousDateDownloaded_lev1=cell(MaxChannelValue,1);
    PreviousDownloadedFile_lev0=cell(MaxChannelValue,1);
    PreviousDownloadedFile_lev1=cell(MaxChannelValue,1);
end


%% preallocation
fromDate_pre=cell(MaxChannelValue,1);
thruDate_pre=cell(MaxChannelValue,1);
fromDate=cell(MaxChannelValue,1);
thruDate=cell(MaxChannelValue,1);
vessel_name=cell(MaxChannelValue,1);
platform_code=cell(MaxChannelValue,1);
platformName=cell(MaxChannelValue,1);
parameterType=cell(MaxChannelValue,1);
metadata_uuid=cell(MaxChannelValue,1);
trip_id=cell(MaxChannelValue,1);


%% Create a list of Channel ID sync with lat, long, metadata_UUID...
for i=1:b
    k=str2double(channelId{i});
    metadata_uuid{k}=V.channel{1,1}.item{1,i}.metadataLink{1,1}.CONTENT;
    try
        trip_id{k}=V.channel{1,1}.item{1,i}.trip{1,1}.CONTENT;
    catch

        [yearFake,monthFake,dayFake]=datevec(V.channel{1,1}.item{1,i}.fromDate{1,1}.CONTENT,'yyyy-mm-ddTHH:MM:SS');
        fake_trip_id=str2num( [ num2str(yearFake) , num2str(monthFake,'%02d'),num2str(dayFake,'%02d')]);
        
        %we create a fake trip id based on the date
        trip_id{k}=num2str(fake_trip_id);
        fprintf('%s - ERROR: No trip id provided by AIMS for channel %d \n',datestr(now),k)
        fprintf('%s - WARNING: trip id generated is %s \n',datestr(now),trip_id{k})

    end
    
    platformName{k}=V.channel{1,1}.item{1,i}.platformName{1,1}.CONTENT;
    platformName{k}=strrep(platformName{k}, ' ', '_'); %remove blank character
    
    %% add vessel name and code
    if ~isempty(strfind(platformName{k},'Ferguson'))
        vessel_name{k}='Cape-Ferguson';
        platform_code{k}='VNCF';
        platformName{k}=strrep(strcat([platform_code{k},' ',vessel_name{k}]),' ','_');
    elseif ~isempty(strfind(platformName{k},'Solander'))
        vessel_name{k}='Solander';
        platform_code{k}='VMQ9273';
        platformName{k}=strrep(strcat([platform_code{k},' ',vessel_name{k}]),' ','_');
    else
        vessel_name{k}='';
        platform_code{k}='';
    end
    
    
end


%% Create a list of available dates to download for each channel
for i=1:length(channelId)
    k=str2double(channelId{i});
    
    fromDate_pre{k}=V.channel{1,1}.item{1,i}.fromDate{1,1}.CONTENT;
    thruDate_pre{k}=V.channel{1,1}.item{1,i}.thruDate{1,1}.CONTENT;
    parameterType{k}=V.channel{1,1}.item{1,i}.parameterType{1,1}.CONTENT;
    parameterType{k}=strrep(parameterType{k}, ' ', '_'); %remove blank character
    
    [yearLaunch,monthLaunch,dayLaunch,hourLaunch,minLaunch,secLaunch]=datevec(fromDate_pre{k},'yyyy-mm-ddTHH:MM:SS');
    fromDate{k}=datestr(datenum([ yearLaunch monthLaunch dayLaunch hourLaunch minLaunch secLaunch]), 'yyyy-mm-ddTHH:MM:SSZ');
    
    %if it's written 'on going', the last date to download is Now
    if strcmpi(thruDate_pre{k},'On Going')
        %         char('data  is on going')
        thruDate{k}=datestr(now,'yyyy-mm-ddTHH:MM:SS');
    else
        [yearEnd,monthEnd,dayEnd,hourEnd,minEnd,secEnd]=datevec(thruDate_pre{k},'yyyy-mm-ddTHH:MM:SS');
        thruDate{k}=datestr(datenum([ yearEnd monthEnd dayEnd hourEnd minEnd secEnd]), 'yyyy-mm-ddTHH:MM:SSZ');
    end
    
    %if nothing has never been downloaded before, the last date is the
    %launch date. We do a try catch, if a new channel, with a number over
    %the preallocation, has been added
    
    if level==0
        try
            if isempty(PreviousDateDownloaded_lev0{k})
                PreviousDateDownloaded_lev0{k}=fromDate{k};
            end
        catch %#ok
            PreviousDateDownloaded_lev0{k}=fromDate{k};
            PreviousDownloadedFile_lev0{k}=[];
        end
    end
    
    if level==1
        try
            if isempty(PreviousDateDownloaded_lev1{k})
                PreviousDateDownloaded_lev1{k}=fromDate{k};
            end
        catch %#ok
            PreviousDateDownloaded_lev1{k}=fromDate{k};
            PreviousDownloadedFile_lev1{k}=[];
        end
    end
end


%% Download the archived and QAQC NetCDF files, move them into proper folders, delete the previous files if data are doubled
t=1; %index to list which channels haven't been able to be downloaded
ChannelIDdown={};

TripDowloaded={};
for i=1:length(channelId)
    k=str2double(channelId{i});
    %     fprintf('%s - Proccessing channel %d\n',datestr(now),k)
    try
        
        %% create a list of monthly files to download
        
        if level==0 && isempty(PreviousDownloadedFile_lev0{k})
            [START,STOP]= ListFileDateSOOP (PreviousDateDownloaded_lev0{k},thruDate{k});
        elseif level==1 && isempty(PreviousDownloadedFile_lev1{k})
            [START,STOP]= ListFileDateSOOP (PreviousDateDownloaded_lev1{k},thruDate{k});
        else
            START=[];STOP=[];filename=[]';%#ok
        end
        
        if ~isempty(START) && ~isempty(STOP)
            fprintf('%s - New channel %d is currently proccessed\n',datestr(now),k)
            [filename,filepath,filenameDate] = DownloadNC_SOOP(START,STOP,k,trip_id{k},level,metadata_uuid{k},vessel_name{k},platform_code{k});
            [yearFile,~,~]=datevec(START,'yyyy-mm-dd');
            modifyNetCDF_Structure(filename,filepath)
            % if one NetCDF has metadata but no data, we report
            % this channel as broken. Nothing
            % is therefor modified in PreviousDownload.mat .
            % Everyday, the script will try again.
            if isNetCDFempty(strcat(filepath,filename))
                fprintf('%s - ERROR: file "%s",channel %d is empty\n',datestr(now),char(filename),k)
                Move_brokenFile_SOOP(platformName{k},parameterType{k},yearFile,filename,filepath,level);
                ChannelIDdown{t}=k;%#ok
                t=t+1;
                filename=[];filenameDate=[];
            end
            
            if ~isempty(filename)
                if isLatLonBad(strcat(filepath,filename))
                    fprintf('%s - ERROR: file "%s",channel %d has bad latitude and longitude data. Need to report to AIMS\n',datestr(now),char(filename),k)
                    Move_brokenFile_SOOP(platformName{k},parameterType{k},yearFile,filename,filepath,level);
                    ChannelIDdown{t}=k;%#ok
                    t=t+1;
                    filename=[];filenameDate=[];
                end
            end
            
            if ~isempty(filename)
                Copy_File_SOOP(DATE_PROGRAM_LAUNCHED,platformName{k},parameterType{k},filename,filepath,level);
                %                     Move_File_SOOP(platformName{k},parameterType{k},yearFile,filename,filepath,level);
                
            end
            
            
            if  ~isempty(filename)  && level==0
                PreviousDownloadedFile_lev0{k}=filename;
                PreviousDateDownloaded_lev0{k}=filenameDate;
            elseif  ~isempty(filename)  && level==1
                PreviousDownloadedFile_lev1{k}=filename;
                PreviousDateDownloaded_lev1{k}=filenameDate;
            end
        else
            fprintf('%s - Channel %d has been already proccessed\n',datestr(now),k)
        end
        
        
    catch ME%#ok
        ChannelIDdown{t}=k;%#ok
        t=t+1;
    end
    
    save(fullfile(SOOP_DownloadFolder,'PreviousDownload.mat'),'-regexp', 'PreviousDateDownloaded_lev1','PreviousDateDownloaded_lev0','PreviousDownloadedFile_lev0','PreviousDownloadedFile_lev1')
    
end


%% Copy and Delete Files to OpenDAP
if exist(strcat(DataFabricFolder,filesep, 'opendap'),'dir') == 7
    fprintf('%s - Data Fabric is connected, SWEET ;) : We are deleting old files, and copying the new ones onto it\n',datestr(now))
    %     fprintf('%s - Here is the list of new folders on the DF:',datestr(now))
    NewFileFoldersDF=DataFabricFileManagement(level);
    for nnFile=1:length(NewFileFoldersDF)
        fprintf('%s - "%s" copied to DataFabric',datestr(now),NewFileFoldersDF{nnFile})
    end
else
    fprintf('%s - ERROR: Data Fabric is NOT connected, BUGGER |-( : Files will be copied next time\n',datestr(now))
end
end