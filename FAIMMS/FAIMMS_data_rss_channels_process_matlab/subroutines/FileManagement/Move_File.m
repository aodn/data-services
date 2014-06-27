function Move_File(channelId,siteName,siteType,parameterType,FolderName,year,filename,filepath,level,DATE_PROGRAM_LAUNCHED)
%% Move_File 
% moves the NetCDF files filename from filepath to a local NewFolder (cf
% down) and creates a list of files to copy to the datafabric.
% This list of files is stored in a txt file for each level file2copy_...
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
%   level           -integer 0 = No QAQC ; 1 = QAQC
%
%
% See also:downloadChannelFAIMMS,FAIMMS_processLevel,DataFabricFileManagement
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 01-Oct-2012

global FAIMMS_DownloadFolder;

switch level
    case 0
        NewFolder=strcat(FAIMMS_DownloadFolder,'/sorted/ARCHIVE/',siteName,filesep,siteType,filesep,parameterType,filesep,FolderName,'_channel_',num2str(channelId),filesep,num2str(year));
    case 1
        NewFolder=strcat(FAIMMS_DownloadFolder,'/sorted/QAQC/',siteName,filesep,siteType,filesep,parameterType,filesep,FolderName,'_channel_',num2str(channelId),filesep,num2str(year));
end


if exist(NewFolder,'dir') == 0
    mkdir(NewFolder);
end

file=fullfile(filepath,filename);
movefile(file,NewFolder);


%we write a list of files to copy to the datafabric
Folderbis=strcat(siteName,filesep,siteType,filesep,parameterType,filesep,FolderName,'_channel_',num2str(channelId),filesep,num2str(year));
filebis=fullfile(Folderbis,filename);
filebis=regexprep(filebis,' ', '\\ ' );

if exist(strcat(FAIMMS_DownloadFolder,'/log_ToDo'),'dir') == 0
            mkdir(strcat(FAIMMS_DownloadFolder,'/log_ToDo'));
end

switch level
    case 0
        Filename_ListFile2copy=fullfile(FAIMMS_DownloadFolder,strcat('log_ToDo/file2copy_RAW_',DATE_PROGRAM_LAUNCHED,'.txt'));
    case 1
        Filename_ListFile2copy=fullfile(FAIMMS_DownloadFolder,strcat('log_ToDo/file2copy_QAQC_',DATE_PROGRAM_LAUNCHED,'.txt'));
end

fid_ListFile2copy = fopen(Filename_ListFile2copy, 'a+');
fprintf(fid_ListFile2copy,'%s \n',filebis);
fclose(fid_ListFile2copy);