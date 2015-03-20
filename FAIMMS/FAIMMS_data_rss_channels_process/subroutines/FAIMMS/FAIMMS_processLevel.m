function FAIMMS_processLevel(levelQC)
%% FAIMMS_processLevel needs an http access to download the xml RSS feed
% for the FAIMMS data. This function needs as well writting access to the
% folder 'dataWIP' in which everything is stored.
% The RSS feed is sustain enough to automate fully the download of data
% from AIMS server to IMOS data server even with new channels, platforms or
% sites.test
%
% The date in the RSS feed is in local time, but the downloaded netcdf file
% is in UTC
% This function has to be run once a day. It checks the last date available of
% data to download for each channel, downloads the new NetCDF file(s) to the
% folder 'dataWIP'/NEW_Downloads/, then move them into
% 'dataWIP'/sorted/ . The last downloaded date for each
% channel is stored in the file 'dataWIP'/PreviousDownload.mat
% For each month, if one more day of data is available, all the data since
% the 1st of the current month is downloaded, and the previous file is
% automaticaly deteled from 'dataWIP'/Sorted ... but not from
% the opendap server. This is why a text file called
% 'dataWIP'/file2delete.txt is created. On each line is written
% the last file to delete on opendap.
%
% example : One\ Tree\ Island/Sensor\ Pole1/temperature/Water\
% Temperature@0.0m\ -channel_2/2010/level0_id2_2010-10-01T00-00-00Z_until_2010-10-08T09-42-37Z.nc
%
% Once a script or the user has deleted the NetCDF file(s), file2delete.txt can be
% deleted as well.
%
%
% Inputs:
%   XML                     - https address of the RSS feed
%   dataWIP   - Folder where data will be daily downloaded
%   dataOpendapRsync        - Main Data Storage Folder
%
% Outputs in 'dataWIP'/ :
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
% Inputs: % Inputs: levelQC        : double 0 or 1 ( RAW, QAQC)
%
%
% Outputs:
%    FAIMMS_Log.txt (stored in dataWIP)
%
% Example:
%    FAIMMS_processLevel(1)
%
% Other m-files required:
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also:
% DataFabricFileManagement,authorisedChannel,createCompareListChannelsToDownloadFAIMMS,
% compareRSSwithPreviousInformationFAIMMS,downloadChannelFAIMMS,CreateSQL_FAIMMS_Table,
% Insert_DB_FAIMMS,UPDATE_qaqc_noqaqc_boolean_DB_FAIMMS
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 24-Aug-2012

warning('off', 'all')
global dataWIP;
global DATE_PROGRAM_LAUNCHED

DATE_PROGRAM_LAUNCHED   = strrep(datestr(now,'yyyymmdd_HHMMAM'),' ','');%the code can be launch everyhour if we want

if exist(dataWIP,'dir') == 0
mkdir(dataWIP);
end


%% xml_url link and SAVING folder
xml_url                 = getenv(['xmlRSS_address_levelQC_' num2str(levelQC)]);

%% Load the RSS fee into a structure
filenameXML             = fullfile(dataWIP,filesep,strcat('FAIMMS_RSS_',DATE_PROGRAM_LAUNCHED,'_',num2str(levelQC),'.xml'));
% [~,statusOnline]      = urlwrite(xml_url, filenameXML); %cached version ! not uptodate
% cmd                   = ['curl -H ''Pragma: no-cache'' -o '  filenameXML ' ' xml_url  ];
cmd                     = ['wget --no-cache --read-timeout=10 -4 -S --debug --output-document='  filenameXML ' ' xml_url  ];
[statusOnline,~]        = system(cmd, '-echo');


if ~statusOnline
    % xmlStructure                                  = xml_parseany(fileread(filenameXML));%Create the
    %     structure from the XML file / OLD toolbox crypted with p-code and not
    %     open source. So can not be used with later released of matlab
    [ faimms_rss ]                                      = xml2struct( filenameXML) ;
    xmlStructure                                        = faimms_rss.rss;

    XMLfolder                                           = strcat(dataWIP,filesep,'XML_archived');
    if exist(XMLfolder,'dir')                           == 0
    mkpath(XMLfolder);
    end
    movefile(filenameXML,XMLfolder);%copy the XML to an archive folder for manual investigation

    %% Create a structure of Channels with their respective sensor names ...
    [channelInfo]                                       = createInformationListfromChannelsFAIMMS_newXML_Toolbox_newXML(xmlStructure);

    %% Find out the channels we have manually authorised to download.
    %New channels to authorised can be done in authorisedChannelList_QAQC
    %or authorisedChannelList_NoQAQC
    [channelInfo.channelId,newChannelsUnauthorisedList] = authorisedChannel(channelInfo.channelId,levelQC);

    %% Compare New data available with what has already been downloaded
    [channelInfo,alreadyDownloaded]                     = createCompareListChannelsToDownloadFAIMMS_newXML(channelInfo,xmlStructure,levelQC);
    [channelInfo,alreadyDownloaded]                     = compareRSSwithPreviousInformationFAIMMS(channelInfo,alreadyDownloaded);

    %% Process each channel
    for ii = 1:length(channelInfo.channelId)

        try
            channelIDToProcess                         = str2double(channelInfo.channelId{ii});
            [alreadyDownloaded,channelInfo,filebroken] = downloadChannelFAIMMS(channelIDToProcess,alreadyDownloaded,channelInfo,levelQC);
            if filebroken == 1
                fprintf('%s - ERROR: with download and process of channel %s.\n',datestr(now),num2str(channelIDToProcess))
            end

        catch err
            fprintf('%s - ERROR: Exception during processing of channel %s \n',datestr(now),num2str(channelIDToProcess))
            rethrow(err)

        end

    end


else
    fprintf('%s - ERROR: AIMS web service is offline.\n',datestr(now))
end