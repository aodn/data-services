function NRS_processLevel(level)
% NRS needs an http access to download the xml RSS feed
% for the NRS data. This function needs as well writting access to the
% folder 'NRS_DownloadFolder' in which everything is stored.
% The RSS feed is sustain enough to automate fully the download of data
% from AIMS server to IMOS data server even with new channels, platforms or
% sites.test
%
% The date in the RSS feed is in local time, but the downloaded netcdf file
% is in UTC
% This function has to be run once a day. It checks the last date available of
% data to download for each channel, downloads the new NetCDF file(s) to the
% folder 'NRS_DownloadFolder'/NEW_Downloads/, then move them into
% 'NRS_DownloadFolder'/sorted/ . The last downloaded date for each
% channel is stored in the file 'NRS_DownloadFolder'/PreviousDownload.mat
% For each month, if one more day of data is available, all the data since
% the 1st of the current month is downloaded, and the previous file is
% automaticaly deteled from 'NRS_DownloadFolder'/Sorted ... but not from
% the opendap server. This is why a text file called
% 'NRS_DownloadFolder'/file2delete.txt is created. On each line is written
% the last file to delete on opendap.
%
% example : One\ Tree\ Island/Sensor\ Pole1/temperature/Water\
% Temperature@0.0m\ -channel_2/2010/level0_id2_2010-10-01T00-00-00Z_until_2010-10-08T09-42-37Z.nc
%
% Once a script or the user has deleted the NetCDF file(s), file2delete.txt can be
% deleted as well.
%
% This function calls finally create_DB_NRS, which writes 3 psql scripts in
% 'NRS_DownloadFolder'to load into pgadmin, or psql (psql -h DatabaseServer
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
%   NRS_DownloadFolder   - Folder where data will be daily downloaded
%   DataFabricFolder        - Main Data Storage Folder
%
% Outputs in 'NRS_DownloadFolder'/ :
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

warning('off', 'all')
global NRS_DownloadFolder;
global DataFabricFolder;
global DATE_PROGRAM_LAUNCHED

DATE_PROGRAM_LAUNCHED=strrep(datestr(now,'yyyymmdd_HHAM'),' ','');%the code can be launch everyhour if we want

if exist(NRS_DownloadFolder,'dir') == 0
    mkdir(NRS_DownloadFolder);
end

%% XML link and SAVING folder
XML=readConfig(['xmlRSS.address.level' num2str(level)], 'config.txt','=');
%XML=strcat('http://data.aims.gov.au/gbroosdata/services/rss/netcdf/level',num2str(level),'/300') ;     %XML file downloaded from the NRS RSS feed

%% Load the RSS fee into a structure
filenameXML=fullfile(NRS_DownloadFolder,strcat('/NRS_RSS_',DATE_PROGRAM_LAUNCHED,'_',num2str(level),'.xml'));
[~,statusOnline]=urlwrite(XML, filenameXML);

if statusOnline
     %     xmlStructure = xml_parseany(fileread(filenameXML));%Create the
    %     structure from the XML file / OLD toolbox crypted with p-code and not
    %     open source. So can not be used with later released of matlab
    [ nrs_rss ] = xml2struct( filenameXML) ;
    xmlStructure = nrs_rss.rss;
    
    XMLfolder=strcat(NRS_DownloadFolder,filesep,'XML_archived');
    if exist(XMLfolder,'dir') == 0
        mkpath(XMLfolder);
    end
    movefile(filenameXML,XMLfolder);
    
    %% initialise MaxChannstrcmpi(filenameUnrenamed,'NO_DATA_FOUND')elValue with b to find the highest value of the ChannelId
    [channelInfo]=createInformationListfromChannelsNRS(xmlStructure);
    
    %% Find out the channels we have manually authorised to download.
    %New channels to authorised can be done in authorisedChannelList_QAQC
    %or authorisedChannelList_NoQAQC
    [channelInfo.channelId,newChannelsUnauthorisedList]=authorisedChannel(channelInfo.channelId,level);
    
    %% Compare New data available with what has already been downloaded
    [channelInfo,alreadyDownloaded]=createCompareListChannelsToDownloadNRS(channelInfo,xmlStructure,level);
    [channelInfo,alreadyDownloaded]=compareRSSwithPreviousInformationNRS(channelInfo,alreadyDownloaded);

    %% Process each channel
    for ii=1:length(channelInfo.channelId)
        
        try
            channelIDToProcess=str2double(channelInfo.channelId{ii});
            [alreadyDownloaded,channelInfo,filebroken]=downloadChannelNRS(channelIDToProcess,alreadyDownloaded,channelInfo,level);
            if filebroken==1
                fprintf('%s - ERROR: with download and process of channel %s.\n',datestr(now),num2str(channelIDToProcess))
            end
            
        catch
            fprintf('%s - ERROR: with download and process of channel %s.\n',datestr(now),num2str(channelIDToProcess))
        end
    end
        
%     %% Create the PSQL scripts to load daily into the database
%     if level == 0
%         CreateSQL_NRS_Table;
%         Insert_DB_NRS_test(channelInfo,alreadyDownloaded)
%     end
%     % Update a column in the parameters table. This is used later for the
%     % reporting, in order to know which channel has QAQC data or RAW or
%     % both
%     UPDATE_qaqc_noqaqc_boolean_DB_NRS(channelInfo,level)
%     
else
    fprintf('%s - ERROR: NRS web service is offline.\n',datestr(now))
end