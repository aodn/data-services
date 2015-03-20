function FAIMMS_Launcher
%% FAIMMS_Launcher - Download of RT FAIMMS data
% This toolbox has been written to download data from the FAIMMS facility
% (Wireless Sensor Networks (FAIMMS)) which is a facility of IMOS. Data is
% downloaded via a web service which converts a http query into a NetCDF
% files. All new data availabe is accessible via an RSS feed provided by
% AIMS. This RSS is then downloaded locally as an XML, then converted into a
% structure by a third party matlab toolbox.
% This structure of channels(sensor), is compared with what has been
% previously downloaded on the last launch of this code. New data available
% is downloaded. A SQL script runs to populate the different tables used for
% geoserver. The files are finally copied and deleted on the datafabric.
%
% Syntax:  FAIMMS_Launcher
%
% Inputs:
%
%
% Outputs:
%    FAIMMS_Log.txt (stored in dataWIP)
%
% Example:
%    FAIMMS_Launcher
%
% Other m-files required:
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also: FAIMMS_processLevel,DataFabricFileManagement,rewriteLog
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 24-Aug-2012

global dataWIP;
global dataOpendapRsync;

WhereAreScripts  = what;
scriptPath       = WhereAreScripts.path;
addpath(genpath(scriptPath));

%location of FAIMMS folders where files will be downloaded
dataWIP          = getenv('data_wip_path');
mkpath(dataWIP);

% source data folder where data will be rsynced to destination (opendap)
dataOpendapRsync = getenv('data_opendap_rsync_path');


% Log File
diary (strcat(dataWIP,filesep,getenv('logfile_name')));

fprintf('%s - START OF PROGRAM\n',datestr(now))
for levelQC = 0 : 1
        fprintf('%s - PROCESSING Level %d\n',datestr(now),levelQC)

        %% Process FAIMMS data for each levelQC
        FAIMMS_processLevel(levelQC);
        %report(levelQC) % to do the reporting of each channel

        %% Copy and Delete Files to OpenDAP . This part of the code can be launched independantly from the rest
        if exist(strcat(dataOpendapRsync,filesep,'opendap'),'dir') == 7
        mkpath(strcat(dataOpendapRsync,filesep,'opendap'));
        end

        fprintf('%s - Deleting old files, and copying the new ones to \n',datestr(now))
        DataFileManagement(levelQC)
        rewriteLog(levelQC)

end

% [status,msg]=FAIMMS_remove_channel(channelID) % in case a channel has to be remove manually, simply type this command
rmpath(genpath(scriptPath))
fprintf('%s - END OF PROGRAM\n',datestr(now))
diary off
end