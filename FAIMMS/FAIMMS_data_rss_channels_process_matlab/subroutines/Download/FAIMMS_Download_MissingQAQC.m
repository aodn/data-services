function ChannelIDdown=FAIMMS_Download_MissingQAQC


%% location of FAIMMS folders
%folder where files will be downloaded
DATE_PROGRAM_LAUNCHED=strrep(datestr(now,'yyyymmdd_HHAM'),' ','');%the code can be launch everyhour if we want

warning('off', 'all')
global FAIMMS_DownloadFolder;
global DataFabricFolder;

if exist(FAIMMS_DownloadFolder,'dir') == 0
    mkdir(FAIMMS_DownloadFolder);
end

%% XML link and SAVING folder
level=0;
XML=strcat('http://data.aims.gov.au/gbroosdata/services/rss/netcdf/level',num2str(level),'/1') ;     %XML file downloaded from the FAIMMS RSS feed

%% Load the RSS fee into a structure
filenameXML=fullfile(FAIMMS_DownloadFolder,strcat('/FAIMMS_RSS_',DATE_PROGRAM_LAUNCHED,'_',num2str(level),'.xml'));
urlwrite(XML, filenameXML);
V = xml_parseany(fileread(filenameXML));                                    %Create the structure from the XML file
delete(filenameXML);
[~,b]=size(V.channel{1,1}.item);                                            %Number of channels available

%% initialise MaxChannelValue with b to find the highest value of the ChannelId
channelId_RAW=cell(b,1);
MaxChannelValue=b;
for i=1:b
    channelId_RAW{i}=V.channel{1,1}.item{1,i}.channelId{1,1}.CONTENT;
    if MaxChannelValue < str2double(channelId_RAW{i});
        MaxChannelValue = str2double(channelId_RAW{i});
    end
end

%% Load the last downloaded date for each channel if available
if exist(fullfile(FAIMMS_DownloadFolder,'PreviousDownload.mat'),'file')
    load (fullfile(FAIMMS_DownloadFolder,'PreviousDownload.mat'))
else
    %     PreviousDateDownloaded_lev0=cell(MaxChannelValue,1);
        PreviousDateDownloaded_lev1=cell(MaxChannelValue,1);
    %     PreviousDownloadedFile_lev0=cell(MaxChannelValue,1);
    PreviousDownloadedFile_lev1=cell(MaxChannelValue,1);
    sensors=cell(MaxChannelValue,1);FolderName=cell(MaxChannelValue,1);
end

if exist(fullfile(FAIMMS_DownloadFolder,'QAQC_RAW_exist.mat'),'file')
    load (fullfile(FAIMMS_DownloadFolder,'QAQC_RAW_exist.mat'))
else
    PreviousDateDownloaded_RAW_Channel=cell(MaxChannelValue,1);
    PreviousDownloadedFile_RAW_Channel=cell(MaxChannelValue,1);
end



%% preallocation
lat=cell(MaxChannelValue,1);
long=cell(MaxChannelValue,1);
fromDate=cell(MaxChannelValue,1);
thruDate=cell(MaxChannelValue,1);
platformName=cell(MaxChannelValue,1);
siteName=cell(MaxChannelValue,1);
parameterType=cell(MaxChannelValue,1);
siteType=cell(MaxChannelValue,1);
title=cell(MaxChannelValue,1);
metadata_uuid=cell(MaxChannelValue,1);
depth=cell(MaxChannelValue,1);
fromDate_bis=cell(MaxChannelValue,1);
thruDate_bis=cell(MaxChannelValue,1);

%% Create a list of Channel ID sync with the type of the sensor ( pole, buoy or weather station), lat, long, metadata_UUID...
for i=1:b
    k=str2double(channelId_RAW{i});
    
    lat{k}=V.channel{1,1}.item{1,i}.lat{1,1}.CONTENT;
    long{k}=V.channel{1,1}.item{1,i}.long{1,1}.CONTENT;
    metadata_uuid{k}=V.channel{1,1}.item{1,i}.metadataLink{1,1}.CONTENT;
    platformName{k}=V.channel{1,1}.item{1,i}.platformName{1,1}.CONTENT;
    parameterType{k}=V.channel{1,1}.item{1,i}.parameterType{1,1}.CONTENT;
    parameterType{k}=strrep(parameterType{k}, ' ', '_'); %remove blank character
    
    if ~isempty(strfind( platformName{k},'Platform')) || ~isempty(strfind( platformName{k},'Weather')) ||...
            ~isempty(strfind( platformName{k},'Base'))
        siteType{k}='Weather Station Platform';
    elseif  ~isempty(strfind( platformName{k},'Sensor Float')) || ~isempty(strfind( platformName{k},'buoy')) ||...
            ~isempty(strfind( platformName{k},'Buoy')) ||  ~isempty(strfind( platformName{k},'SF'))
        siteType{k}=char(strcat('Sensor Float',[{' '}],regexp(platformName{k},'\d+','match')));
    elseif  ~isempty(strfind( platformName{k},'Pole')) || ~isempty(strfind( platformName{k},'RP'))
        siteType{k}=char(strcat('Relay Pole',[{' '}],regexp(platformName{k},'\d+','match')));
    else
        siteType{k}='UNKNOWN';
    end
    
    
    siteName{k}=V.channel{1,1}.item{1,i}.siteName{1,1}.CONTENT;
    title{k}=V.channel{1,1}.item{1,i}.title{1,1}.CONTENT;
    
    if ~isempty(strfind( title{k},'@'))
        logical_Depth=1;
        indexStartbis=strfind( title{k},'@');
        indexstop=strfind( title{k}(indexStartbis+1:end),'m')-1;
        depth{k}=strcat(title{k}(indexStartbis+1:indexStartbis+indexstop(1)));
    else
        logical_Depth=0;
        depth{k}=num2str(0);
    end
    
    
    sensors{k}=parameterType{k};
    sensors{k}=strrep(sensors{k}, ' ', '_'); %remove blank character
    
    if logical_Depth
        FolderName{k}=strcat(sensors{k},'@',num2str(depth{k}),'m');
    else
        FolderName{k}=sensors{k};
    end
    
    siteType{k}=strrep(siteType{k}, ' ', '_'); %remove blank character
    siteName{k}=strrep(siteName{k}, ' ', '_'); %remove blank character
    
    fromDate{k}=V.channel{1,1}.item{1,i}.fromDate{1,1}.CONTENT;
    thruDate{k}=V.channel{1,1}.item{1,i}.thruDate{1,1}.CONTENT;
end


%% Create a list of dates to download for each RAW channel that is non
%% existant in QAQC


RawChannelToDownload=[];
RawChannelToRemove=[];
for i=1:length(channelId_RAW)
    k=str2double(channelId_RAW{i});
    if isempty(PreviousDownloadedFile_lev1{k}) 
        RawChannelToDownload=[k,RawChannelToDownload];
        
    elseif ~isempty(PreviousDownloadedFile_lev1{k}) && ~isempty(PreviousDownloadedFile_RAW_Channel{k}) %when QAQC procedures finally exist for one channel and QAQC channel has been downloaded
        RawChannelToRemove=[k,RawChannelToRemove];
        PreviousDownloadedFile_RAW_Channel{k}=[];
        PreviousDateDownloaded_RAW_Channel{k}=[];
    end
end
% datenum(PreviousDateDownloaded_lev1{k},'yyyy-mm-ddTHH:MM:SS')
% <datenum(PreviousDateDownloaded_RAW_Channel{k},'yyyy-mm-ddTHH:MM:SS')

for i=1:length(RawChannelToDownload)
    k=RawChannelToDownload(i);
  
    try
        if isempty(PreviousDateDownloaded_RAW_Channel{k})
            PreviousDateDownloaded_RAW_Channel{k}=fromDate{k};
        end
    catch %#ok
        PreviousDateDownloaded_RAW_Channel{k}=fromDate{k};
        PreviousDownloadedFile_RAW_Channel{k}=[];
    end 
    clear  fromDate_bis thruDate_bis
end




t=1; %index to list which channels haven't been able to be downloaded
ChannelIDdown={};


for ii=1:length(RawChannelToDownload)
    k=RawChannelToDownload(ii);
    clear  filename filenameDate filepath filename_pre filenameDate_pre filepath_pre
    
    %% create a list of monthly files to download for each level
    [START,STOP,Last2Delete]= ListFileDate (PreviousDateDownloaded_RAW_Channel{k},thruDate{k});
    
    
    try
        if isempty(PreviousDownloadedFile_RAW_Channel{k}) % we test if we have ever downloaded anything for ...
            %a specific channel, in the case that it is available
            %just for one single month. If we don't do that, Last2Delete=1
            %and the file would be deleted by mistake
            Last2Delete=0;
        end
    catch %#ok
        Last2Delete=0;
    end
    
    
    if ~isempty(START) && ~isempty(STOP)  % START and STOP will be empty if one file has already been downloaded for the current day
        for j=1:size(START,2)             % j is the number of files to download for each channel
            [filenameUnrenamed,filepath,~] = DownloadNC(START{j},STOP{j},k,level,metadata_uuid{k});
            if ~isempty(filenameUnrenamed) && ~isempty(filepath)
                filenameUnrenamed=ChangeNetCDF_Structure(filenameUnrenamed,filepath,str2double(long{k}),str2double(lat{k}));
            end
            
            
            % if one NetCDF has been downloaded but doesn't have
            % metadata nor data, this is normal. This means no data for
            % this time period. The channel might have some data after
            % a period of silence though.
            if ~isempty(filenameUnrenamed) && ~isempty(filepath)
                [yearFile,~,~]=datevec(START{j},'yyyy-mm-dd');
                
                [sensors{k},filenameDate,filename] = NetCDF_getinfo (filepath,filenameUnrenamed);
                %                     FolderName{k}=strcat(sensors{k},'@',num2str(depth{k}),'m');
                
                if ~isNetCDFempty(strcat(filepath,filename))
                    Move_File_missingQAQC(k,siteName{k},parameterType{k},siteType{k},FolderName{k},yearFile,filename,filepath,level,DATE_PROGRAM_LAUNCHED);
                    filename_pre=filename;filenameDate_pre=filenameDate; % we keep the last good one
                    filebroken=0;
                else
                    % if one NetCDF has metadata but no data, we report
                    % this channel as broken, go out of the loop. Nothing
                    % is therefor modified in PreviousDownload.mat .
                    % Everyday, the script will try again.
                    
                    ChannelIDdown{t}=k;%#ok
                    t=t+1;
                    Move_brokenFile(k,siteName{k},parameterType{k},siteType{k},FolderName{k},yearFile,filename,filepath,level);
                    if exist('filename_pre','var') && exist('filenameDate_pre','var')
                        filename=filename_pre;filenameDate=filenameDate_pre;
                    else
                        filename=[];filenameDate=[];
                    end
                    filebroken=1;
                    %                         break
                end
            else
                
                % this means that the zip file is completely empty, the channel has
                % therefor a problem
                ChannelIDdown{t}=k;%#ok
                t=t+1;
                filebroken=1;
                
                filename= [];
                filenameDate=[];
                
            end
            
            
            
            %Last2Delete is a boolean,
            if    Last2Delete==1 && ~isempty(filename) && filebroken==0
                File2Delete=PreviousDownloadedFile_RAW_Channel{k};
                %                 [yearFile2Delete,~,~]=datevec(PreviousDateDownloaded_lev0{k},'yyyy');
                [yearFile2Delete,~,~]=datevec(regexpi(File2Delete,'(*\d*','match','once'),'yyyymmdd');
                
                DeleteFile_missingQAQC(k,siteName{k},parameterType{k},siteType{k},FolderName{k},yearFile2Delete,File2Delete,level,DATE_PROGRAM_LAUNCHED);
                
                PreviousDownloadedFile_RAW_Channel{k}=filename;
                PreviousDateDownloaded_RAW_Channel{k}=filenameDate;
                
                Last2Delete=0; % we resume Last2Delete not to delete the last good downloaded file. REALLY IMPORTANT
                
                
            elseif Last2Delete==0 && ~isempty(filename) && filebroken==0
                
                PreviousDownloadedFile_RAW_Channel{k}=filename;
                PreviousDateDownloaded_RAW_Channel{k}=filenameDate;
                
                
            end
            
        end
    end
end


ChannelIDdown=unique(cell2mat(ChannelIDdown));
disp(ChannelIDdown)
save(fullfile(FAIMMS_DownloadFolder,'QAQC_RAW_exist.mat'),'-regexp', 'PreviousDateDownloaded_RAW_Channel','PreviousDownloadedFile_RAW_Channel')



%% Copy and Delete Files to OpenDAP
if exist(strcat(DataFabricFolder,'opendap'),'dir') == 7
    disp('Data Fabric is connected, SWEET ;) : We are deleting old files, and copying the new ones onto it')
    DataFabricFileManagement_MissingQAQC
else
    disp('Data Fabric is NOT connected, BUGGER |-( : Files will be copied next time')
end

%% once a channel's procedure has been configured and therfor exist in the
%% QAQC rss feed. we delete all the folders NO_QAQC_DATA for this channel
%% from the DF

if ~isempty(RawChannelToRemove)
    LogFoldersToDelete=fullfile(FAIMMS_DownloadFolder,strcat('log_ToDo/NoQAQCfolders2delete_',DATE_PROGRAM_LAUNCHED));
    for ii=1:length(RawChannelToRemove)
        
        k=RawChannelToRemove(ii);
        [yearStart,~,~,~,~,~]=datevec(fromDate{k},'yyyy');
        [yearEnd,~,~,~,~,~]=datevec(thruDate{k},'yyyy');
        
        for jj=yearStart:yearEnd
            Folder2Remove=strcat(siteName{k},filesep,siteType{k},filesep,parameterType{k},filesep,FolderName{k},'_channel_',num2str(k),filesep,num2str(jj),filesep,'NO_QAQC_DATA');
            fid_LogFoldersToDelete = fopen(LogFoldersToDelete, 'a+');
            fprintf(fid_LogFoldersToDelete,'%s \n',Folder2Remove);
        end
    end
    fclose(fid_LogFoldersToDelete);
end
removeRAW


%% Create the PSQL scripts to load daily into the database
channelId=sort(str2double(channelId_RAW));
Insert_DB_FAIMMS(channelId,siteName,siteType,FolderName,long,lat,sensors,parameterType,fromDate,thruDate,metadata_uuid,depth)


