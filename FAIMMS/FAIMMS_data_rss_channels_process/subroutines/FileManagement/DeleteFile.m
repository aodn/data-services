function DeleteFile (channelId,siteName,siteType,parameterType,FolderName,year,filename,levelQC,DATE_PROGRAM_LAUNCHED)
%% DeleteFile 
% creates a list of NetCDF files which have to be deleted from the
% datafabric. Because each file is always downloaded from the 1st of each
% month until the last date of data availability, it is necessary to delete
% the previous file downloaded of the same month.
% This list of files is stored in a txt file for each levelQC file2delete...
% It is used by DataFabricFileManagement.m
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
%   filepath        -Cell array of their relative paths
%   levelQC           -integer 0 = No QAQC ; 1 = QAQC
%   DATE_PROGRAM_LAUNCHED 
% Outputs:
%   file2delete.txt - text file of NetCDF files to delete on opendap
%
% See also:downloadChannelFAIMMS,FAIMMS_processLevel,DataFabricFileManagement
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 01-Oct-2012

global dataWIP;

%fileDirPath where the file is according to the levelQC, No QAQC or QAQC

subDirData = strcat(siteName,filesep,siteType,filesep,parameterType,filesep,FolderName,'_channel_',num2str(channelId),filesep,num2str(year));
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

if exist(fileDirPath,'dir')
    delete(fullfile(fileDirPath,filename));
    filepathWithoutWorkingDirectory = fullfile(fileDirPathSuffixe,filename);
end

%we write a list of files to delete 
filepathWithoutWorkingDirectory=regexprep(filepathWithoutWorkingDirectory,' ', '\\ ' );
filepathWithoutWorkingDirectory = fullfile(subDirData,filename);
filepathWithoutWorkingDirectory = regexprep(filepathWithoutWorkingDirectory,' ', '\\ ' );



if exist(strcat(dataWIP,'/log_ToDo'),'dir') == 0
    mkpath(strcat(dataWIP,'/log_ToDo'));
end

switch levelQC
    case 0
        Filename_ListFile2delete=fullfile(dataWIP,strcat('log_ToDo/file2delete_RAW_',DATE_PROGRAM_LAUNCHED,'.txt'));
    case 1
        Filename_ListFile2delete=fullfile(dataWIP,strcat('log_ToDo/file2delete_QAQC_',DATE_PROGRAM_LAUNCHED,'.txt'));
end

fid_ListFile2delete = fopen(Filename_ListFile2delete, 'a+');
fprintf(fid_ListFile2delete,'%s \n',filepathWithoutWorkingDirectory);
fclose(fid_ListFile2delete);