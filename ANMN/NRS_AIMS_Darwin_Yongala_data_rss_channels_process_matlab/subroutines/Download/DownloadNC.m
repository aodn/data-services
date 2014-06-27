function [filename,filepath,filenameDate,AIMS_server_online] = DownloadNC(START,STOP,channelId,level,metadata_uuid)
% DownloadNC downloads a list of NetCDF files
%
% Inputs:   START       -the start date of the file to download
%           STOP        -the stop date of the file to download
%           channelId   -the channel ID delivered by FAIMMS to sort out the
%                        different sensors.
%           level       -integer 0 = No QAQC ; 1 = QAQC
%
% Outputs:  filename    - name of the downloaded file
%           filepath    - path of the downloaded file
%           filenameDate- is the STOP date written in another format
%
%
% See also:downloadChannelNRS,NRS_processLevel
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 01-Oct-2012
%
global NRS_DownloadFolder;

filepath=strcat(NRS_DownloadFolder,filesep,'NEW_Downloads/');
%[year,~,~]=datevec(START,'yyyy-mm-dd');


if exist(filepath,'dir') == 0
    mkdir(filepath);
end

%% Archive or QAQC
switch level
    case 0
        level2download='level0';
    case 1
        level2download='level1';
end

%% we download the file with a server_test
url=strcat('http://data.aims.gov.au/gbroosdata/services/data/rtds/',num2str(channelId),'/',level2download,'/raw/raw/',START,'/',STOP,'/netcdf/2');
AIMS_server_online=0;
TimeElapsed=0;
while AIMS_server_online==0 && TimeElapsed < 121
    tic;
    try
        ncmFiles=unzip(url,filepath);
        AIMS_server_online=1;
        TimeElapsed=0;        
    catch
        fprintf('%s - ERROR: Server Unavailable, we wait 5 secs\n',datestr(now))
        AIMS_server_online=0;
        pause(5);
        TimeElapsed=toc+TimeElapsed;
        ncmFiles = url;
    end
end

%% add metadata_uuid&Channel Id into the NetCDF file
if isempty(strfind(char(ncmFiles),'NO_DATA_FOUND'))
    try
        nc = netcdf.open(ncmFiles{1},'NC_WRITE');
        netcdf.reDef(nc)
        netcdf.putAtt(nc,netcdf.getConstant('NC_GLOBAL'),'aims_channel_id', num2str(channelId));
        if ~strcmpi(metadata_uuid,'Not Available')
            netcdf.putAtt(nc,netcdf.getConstant('NC_GLOBAL'),'metadata_uuid', strcat(metadata_uuid));
        end
        netcdf.endDef(nc)
        netcdf.close(nc);
        
        A=textscan((ncmFiles{1}),'%s', 14, 'delimiter', '/');
        filename=A{1}{size(A{1},1),1};
        
        [year,month,day]=datevec(STOP,'yyyy-mm-dd');
        filenameDate=strcat(datestr(datenum([ year month day]), 'yyyy-mm-dd'),'T00:00:00');
    catch
        %file is empty, there is a problem in the channel
        fprintf('%s - ERROR: Downloaded file "%s" could not be open\n',datestr(now),char(ncmFiles))
        filename=[];
        filepath=[];
        filenameDate=[];
    end
else
    filename='NO_DATA_FOUND';
    filepath=[];
    filenameDate=[];
end