function [filename,filepath,filenameDate] = DownloadNC_SOOP(START,STOP,channelId,tripId,level,metadata_uuid,vessel_name,platform_code)
% DownloadNC downloads a list of NetCDF files
%
% Inputs:   START       -the start date of the file to download
%           STOP        -the stop date of the file to download
%           channelId   -the channel ID delivered by FAIMMS to sort out the
%                        different sensors.
%           level       -integer 0 = No QAQC ; 1 = QAQC
%           metadata_uuid-Mest Metadata unique code identifier
%
% Outputs:  filename    - name of the downloaded file
%           filepath    - path of the downloaded file
%           filenameDate- is the STOP date written in another format
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
global SOOP_DownloadFolder;

filepath=strcat(SOOP_DownloadFolder,'/NEW_Downloads/');
% [year,~,~]=datevec(START,'yyyy-mm-dd');


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
        ncmFiles=[];
    end
end

%% add metadata_uuid&Channel Id into the NetCDF file
if isempty(strfind(char(ncmFiles),'NO_DATA_FOUND'))
    try
        nc = netcdf.open(ncmFiles{1},'NC_WRITE');
        netcdf.reDef(nc)
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'aims_channel_id', num2str(channelId));
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'cdm_data_type','Trajectory');
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'vessel_name',vessel_name);
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'platform_code',platform_code);
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'trip_id',num2str(tripId));
        
        if ~strcmpi(metadata_uuid,'Not Available')
            netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'metadata_uuid', strcat(metadata_uuid));
        end
        netcdf.endDef(nc)
        netcdf.close(nc);
               
        A=textscan((ncmFiles{1}),'%s', 14, 'delimiter', '/');
        filename=A{1}{size(A{1},1),1};
        
        [year,month,day]=datevec(STOP,'yyyy-mm-dd');
        filenameDate=strcat(datestr(datenum([ year month day]), 'yyyy-mm-dd'),'T00:00:00');
        
        
        %% modification of the filename DATE, completely messy, local time as UTC !
        nc = netcdf.open(strcat(filepath,filename),'NC_NOWRITE');
        
        %% list all the Variables
        [VARNAME,VARATTS]=listVarNC(nc);
    
        %% we grab the date dimension
        idxTIME= strcmpi(VARNAME,'TIME')==1;
        TimeVarName=VARNAME{idxTIME};
        varidTIME=netcdf.inqDimID(nc,TimeVarName);
        [~, dimlenTIME] = netcdf.inqDim(nc,varidTIME);
    
        if dimlenTIME >0        
            [~,~,firstDateNum,lastDateNum]= getTimeOffsetNC(nc,VARNAME);
           % we write the time (which is in UTC) in good UTC format in the NcFile
            filenameNew=regexprep(filename,'Z_','_'); %remove the Z first if there is any
            filenameNew=regexprep(filenameNew, '\d[\dT]+', datestr(firstDateNum,'yyyymmddTHHMMSSZ'),'once'); % if there is a + , it is incoherent.
            filenameNew=regexprep(filenameNew, '_END-[\dT]+', strcat('_END-',datestr(lastDateNum,'yyyymmddTHHMMSSZ')),1); % if there is a + , it is incoherent.
            
            netcdf.close(nc);
            if ~strcmp(filenameNew,filename)
                movefile(strcat(filepath,filename),strcat(filepath,filenameNew));
            end
            
        else
            netcdf.close(nc);
            filenameNew=filename;
        end
        
        
        filename=filenameNew;
    catch
        %file is empty, there is a problem in the channel
        %not working why ?
        fprintf('%s - ERROR: Downloaded file "%s" could not be open\n',datestr(now),char(ncmFiles{1}))
        filename=[];
        filepath=[];
        filenameDate=[];
    end
else
    filename='';
    filepath=[];
    filenameDate=[];
end
