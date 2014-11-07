function Move_File(channelId,siteName,siteType,parameterType,FolderName,year,filename,sourcePath,levelQC,DATE_PROGRAM_LAUNCHED)
%% Move_File 
% moves the NetCDF files filename from sourcePath to a local filePathDestination (cf
% down) and creates a list of files to copy to the datafabric.
% This list of files is stored in a txt sourceFile for each levelQC file2copy_...
% It is used by DataFabricFileManagement.m
%
% Inputs:
%   channelId       -Cell array of online channels (270)
%   siteName        -Cell array of site_codes (Lizard Island)
%   siteType        -Cell array of platform_codes (Weather Station
%                    Platform)
%   FolderName      -Cell array of one part of the folder structure of a
%                    NetCDF sourceFile
%   year            -Cell array of data years of the files to delete
%   parameterType   -Cell array of parameters (temperature)
%   filename        -Cell array of files to delete
%   sourcePath        -Cell array of their relative paths
%   levelQC           -integer 0 = No QAQC ; 1 = QAQC
%
%
% See also:downloadChannelFAIMMS,FAIMMS_processLevel,DataFabricFileManagement
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 01-Oct-2012

global dataWIP;

subFolderData = strcat(siteName,filesep,siteType,filesep,parameterType,filesep,FolderName,'_channel_',num2str(channelId),filesep,num2str(year));

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


%we write a list of files to copy
filePathSuffixe = strcat(subFolderData);
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