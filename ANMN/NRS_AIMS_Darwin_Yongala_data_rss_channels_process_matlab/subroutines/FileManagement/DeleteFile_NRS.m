function DeleteFile_NRS(channelId,siteName,parameterType,FolderName,year,filename,levelQC,DATE_PROGRAM_LAUNCHED)
% DeleteFile deletes a list of NetCDF files which are doubled.
%
% Inputs:
%   channelId       -Cell array of online channels (270)
%   siteName        -Cell array of site_codes (Lizard Island)
%                    Platform)
%   FolderName      -Cell array of one part of the folder structure of a
%                    NetCDF file
%   year            -Cell array of data years of the files to delete
%   parameterType   -Cell array of parameters (temperature)
%   filename        -Cell array of files to delete
%   filepath        -Cell array of their relative paths
%   levelQC           -integer 0 = No QAQC ; 1 = QAQC
%
% Outputs:
%   file2delete.txt - text file of NetCDF files to delete on opendap
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
global dataWIP;

siteDAR = readConfig('siteDAR.name', 'config.txt','=');
siteYON = readConfig('siteYON.name', 'config.txt','=');

if strcmp(siteName,'Yongala')
    site = siteYON;
elseif strcmp(siteName,'Darwin')
    site = siteDAR;
else
    site = 'UNKNOWN';
end

subDirData = strcat(site,filesep,parameterType,filesep,FolderName,'_channel_',num2str(channelId),filesep,num2str(year));


%Folder where the file is according to the levelQC, No QAQC or QAQC
switch levelQC
    case 0
        fileDirPathSuffixe = strcat('ARCHIVE/',subDirData,filesep);
        fileDirPath = strcat(dataWIP,'/sorted/',fileDirPathSuffixe);
    case 1
        fileDirPathSuffixe = strcat('/QAQC/',subDirData,filesep);
        fileDirPath = strcat(dataWIP,'/sorted/',fileDirPathSuffixe);

end

%Same folder but without the root, so we keep track of the file to delete
%in another hard drive if the latter is not sync with the main one
% fileDirPathSuffixe=strcat('',siteName,filesep,siteType,filesep,parameterType,filesep,FolderName,'channel_',num2str(channelID),filesep,num2str(year));

if exist(fileDirPath,'dir')
    delete(fullfile(fileDirPath,filename));
    filepathWithoutWorkingDirectory = fullfile(fileDirPathSuffixe,filename);
end

filepathWithoutWorkingDirectory = regexprep(filepathWithoutWorkingDirectory,' ', '\\ ' );

%we write a list of files to delete from the datafabric
filepathWithoutWorkingDirectory = fullfile(subDirData,filename);
filepathWithoutWorkingDirectory = regexprep(filepathWithoutWorkingDirectory,' ', '\\ ' );


switch levelQC
    case 0
        Filename_ListFile2delete=fullfile(dataWIP,strcat('log_ToDo/file2delete_RAW_',DATE_PROGRAM_LAUNCHED,'.txt'));
    case 1
        Filename_ListFile2delete=fullfile(dataWIP,strcat('log_ToDo/file2delete_QAQC_',DATE_PROGRAM_LAUNCHED,'.txt'));
end

fid_ListFile2delete = fopen(Filename_ListFile2delete, 'a+');
fprintf(fid_ListFile2delete,'%s \n',filepathWithoutWorkingDirectory);
fclose(fid_ListFile2delete);