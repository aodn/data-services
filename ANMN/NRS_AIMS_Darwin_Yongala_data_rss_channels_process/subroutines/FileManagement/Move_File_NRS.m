function Move_File_NRS(channelId,siteName,parameterType,FolderName,year,filename,sourcePath,levelQC,DATE_PROGRAM_LAUNCHED)
% Move_File moves the NetCDF files filename from sourcePath to filePathDestination (cf
%
%
% Inputs:
%   channelId       -Cell array of online channels (270)
%   siteName        -Cell array of site_codes (Lizard Island)
%   siteType        -Cell array of platform_codes (Weather Station
%                    Platform)
%   FolderName      -Cell array of one part of the folder structure of a
%                    NetCDF file
%   year            -Cell array of data years of the files to delete
%   parameterType   -Cell array of parameters (temperature)
%   filename        -Cell array of files to delete
%   sourcePath        -Cell array of their relative paths
%
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
dataWIP = getenv('data_wip_path');

siteDAR = getenv('site_darwin_name');
siteYON = getenv('site_yongala_name');

if strcmp(siteName,'Yongala')
    site = siteYON;
elseif strcmp(siteName,'Darwin')
    site = siteDAR;
else
    site = 'UNKNOWN';
end


subFolderData = strcat(site,filesep,parameterType,filesep,FolderName,'_channel_',num2str(channelId),filesep,num2str(year));

switch levelQC
    case 0
        filePathDestination = strcat(dataWIP,'/sorted/ARCHIVE/',subFolderData);
    case 1
        filePathDestination = strcat(dataWIP,'/sorted/QAQC/',subFolderData);
end


if exist(filePathDestination,'dir') == 0
    mkpath(filePathDestination);
end

sourceFile = fullfile(sourcePath,filename);
movefile(sourceFile,filePathDestination);


%we write a list of files to copy to the datafabric
filePathSuffixe = fullfile(subFolderData,filename);
filePathSuffixe = regexprep(filePathSuffixe,' ', '\\ ' );
if exist(strcat(dataWIP,'/log_ToDo'),'dir') == 0
    mkdir(strcat(dataWIP,'/log_ToDo'));
end


switch levelQC
    case 0
        Filename_ListFile2copy=fullfile(dataWIP,strcat('log_ToDo/file2copy_RAW_',DATE_PROGRAM_LAUNCHED,'.txt'));
    case 1
        Filename_ListFile2copy=fullfile(dataWIP,strcat('log_ToDo/file2copy_QAQC_',DATE_PROGRAM_LAUNCHED,'.txt'));
end

fid_ListFile2copy = fopen(Filename_ListFile2copy, 'a+');
fprintf(fid_ListFile2copy,'%s \n',filePathSuffixe);
fclose(fid_ListFile2copy);