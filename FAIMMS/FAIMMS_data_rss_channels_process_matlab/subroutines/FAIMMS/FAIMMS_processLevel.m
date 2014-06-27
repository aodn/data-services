function FAIMMS_processLevel(level)
%% FAIMMS_processLevel needs an http access to download the xml RSS feed
% for the FAIMMS data. This function needs as well writting access to the
% folder 'FAIMMS_DownloadFolder' in which everything is stored.
% The RSS feed is sustain enough to automate fully the download of data
% from AIMS server to IMOS data server even with new channels, platforms or
% sites.test
%
% The date in the RSS feed is in local time, but the downloaded netcdf file
% is in UTC
% This function has to be run once a day. It checks the last date available of
% data to download for each channel, downloads the new NetCDF file(s) to the
% folder 'FAIMMS_DownloadFolder'/NEW_Downloads/, then move them into
% 'FAIMMS_DownloadFolder'/sorted/ . The last downloaded date for each
% channel is stored in the file 'FAIMMS_DownloadFolder'/PreviousDownload.mat
% For each month, if one more day of data is available, all the data since
% the 1st of the current month is downloaded, and the previous file is
% automaticaly deteled from 'FAIMMS_DownloadFolder'/Sorted ... but not from
% the opendap server. This is why a text file called
% 'FAIMMS_DownloadFolder'/file2delete.txt is created. On each line is written
% the last file to delete on opendap.
%
% example : One\ Tree\ Island/Sensor\ Pole1/temperature/Water\
% Temperature@0.0m\ -channel_2/2010/level0_id2_2010-10-01T00-00-00Z_until_2010-10-08T09-42-37Z.nc
%
% Once a script or the user has deleted the NetCDF file(s), file2delete.txt can be
% deleted as well.
%
% This function calls finally create_DB_FAIMMS, which writes 3 psql scripts in
% 'FAIMMS_DownloadFolder'to load into pgadmin, or psql (psql -h DatabaseServer
% -U user -W password -d maplayers -p port < file.sql ) in the following order :
%   1.DB_TABLE_sites.sql
%   2.DB_TABLE_platforms.sql
%   3.DB_TABLE_parameters.sql
%
% All three tables should be loaded at each run of this script into the
% Database after having previously dropped the old ones in reverse order
% (because of foreign keys).
%
% Inputs:
%   XML                     - https address of the RSS feed
%   FAIMMS_DownloadFolder   - Folder where data will be daily downloaded
%   DataFabricFolder        - Main Data Storage Folder
%
% Outputs in 'FAIMMS_DownloadFolder'/ :
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
% Syntax:  FAIMMS_Launcher
%
% Inputs: % Inputs: level        : double 0 or 1 ( RAW, QAQC)
%
%
% Outputs:
%    FAIMMS_Log.txt (stored in FAIMMS_DownloadFolder)
%
% Example:
%    FAIMMS_processLevel(1)
%
% Other m-files required:readConfig
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also:
% readConfig,DataFabricFileManagement,authorisedChannel,createCompareListChannelsToDownloadFAIMMS,
% compareRSSwithPreviousInformationFAIMMS,downloadChannelFAIMMS,CreateSQL_FAIMMS_Table,
% Insert_DB_FAIMMS,UPDATE_qaqc_noqaqc_boolean_DB_FAIMMS
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 24-Aug-2012

warning('off', 'all')
global FAIMMS_DownloadFolder;
global DATE_PROGRAM_LAUNCHED

DATE_PROGRAM_LAUNCHED=strrep(datestr(now,'yyyymmdd_HHAM'),' ','');%the code can be launch everyhour if we want. This date is used for the log files

if exist(FAIMMS_DownloadFolder,'dir') == 0
    mkdir(FAIMMS_DownloadFolder);
end

%% XML RSS feed address
XML=readConfig(['xmlRSS.address.level' num2str(level)], 'config.txt','=');
%XML=strcat('http://data.aims.gov.au/gbroosdata/services/rss/netcdf/level',num2str(level),'/1') ;%XML file downloaded from the FAIMMS RSS feed

%% Load the RSS feed into a structure
filenameXML=fullfile(FAIMMS_DownloadFolder,strcat('/FAIMMS_RSS_',DATE_PROGRAM_LAUNCHED,'_',num2str(level),'.xml'));
[~,statusOnline]=urlwrite(XML, filenameXML);

if statusOnline
    %     xmlStructure = xml_parseany(fileread(filenameXML));%Create the
    %     structure from the XML file / OLD toolbox crypted with p-code and not
    %     open source. So can not be used with later released of matlab
    [ faimms_rss ] = xml2struct( filenameXML) ;
    xmlStructure = faimms_rss.rss;
    
    XMLfolder=strcat(FAIMMS_DownloadFolder,filesep,'XML_archived');
    if exist(XMLfolder,'dir') == 0
        mkpath(XMLfolder);
    end
    movefile(filenameXML,XMLfolder);%copy the XML to an archive folder for manual investigation
    
    %% Create a structure of Channels with their respective sensor names ...
    [channelInfo] = createInformationListfromChannelsFAIMMS_newXML_Toolbox_newXML(xmlStructure);
    %     [channelInfo]=createInformationListfromChannelsFAIMMS(xmlStructure);
    
    %% Find out the channels we have manually authorised to download.
    %New channels to authorised can be done in authorisedChannelList_QAQC
    %or authorisedChannelList_NoQAQC
    [channelInfo.channelId,newChannelsUnauthorisedList]=authorisedChannel(channelInfo.channelId,level);
    
    %% Compare New data available with what has already been downloaded
    %     [channelInfo,alreadyDownloaded]=createCompareListChannelsToDownloadFAIMMS(channelInfo,xmlStructure,level);
    [channelInfo,alreadyDownloaded] = createCompareListChannelsToDownloadFAIMMS_newXML(channelInfo,xmlStructure,level);
    [channelInfo,alreadyDownloaded]=compareRSSwithPreviousInformationFAIMMS(channelInfo,alreadyDownloaded);
    
    %% Process each channel
    for ii=1:length(channelInfo.channelId)
        
        try
            channelIDToProcess=str2double(channelInfo.channelId{ii});
            [alreadyDownloaded,channelInfo,filebroken]=downloadChannelFAIMMS(channelIDToProcess,alreadyDownloaded,channelInfo,level);
            if filebroken==1
                fprintf('%s - ERROR: with download and process of channel %s.\n',datestr(now),num2str(channelIDToProcess))
            end
            
        catch
            fprintf('%s - ERROR: with download and process of channel %s.\n',datestr(now),num2str(channelIDToProcess))
        end
    end
    
    %% Create the PSQL scripts to load daily into the database
    if level == 0
        CreateSQL_FAIMMS_Table;
        Insert_DB_FAIMMS(channelInfo,alreadyDownloaded)
    end
    % Update a column in the parameters table. This is used later for the
    % reporting, in order to know which channel has QAQC data or RAW or
    % both
    UPDATE_qaqc_noqaqc_boolean_DB_FAIMMS(channelInfo,level)
    
else
    fprintf('%s - ERROR: FAIMMS web service is offline.\n',datestr(now))
end