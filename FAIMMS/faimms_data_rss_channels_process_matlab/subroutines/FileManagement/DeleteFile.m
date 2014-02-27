function DeleteFile (channelId,siteName,siteType,parameterType,FolderName,year,filename,level,DATE_PROGRAM_LAUNCHED)
%% DeleteFile 
% creates a list of NetCDF files which have to be deleted from the
% datafabric. Because each file is always downloaded from the 1st of each
% month until the last date of data availability, it is necessary to delete
% the previous file downloaded of the same month.
% This list of files is stored in a txt file for each level file2delete...
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

global FAIMMS_DownloadFolder;

%Folder where the file is according to the level, No QAQC or QAQC
switch level
    case 0
        Folder=strcat(FAIMMS_DownloadFolder,'/sorted/ARCHIVE/',siteName,filesep,siteType,filesep,parameterType,filesep,FolderName,'_channel_',num2str(channelId),filesep,num2str(year));
    case 1
        Folder=strcat(FAIMMS_DownloadFolder,'/sorted/QAQC/',siteName,filesep,siteType,filesep,parameterType,filesep,FolderName,'_channel_',num2str(channelId),filesep,num2str(year));
end

%Same folder but without the root, so we keep track of the file to delete
%in another hard drive if the latter is not sync with the main one
Folderbis=strcat(siteName,filesep,siteType,filesep,parameterType,filesep,FolderName,'_channel_',num2str(channelId),filesep,num2str(year));

if exist(Folder,'dir')    
    file=fullfile(Folder,filename);
    delete(file);
    filebis=fullfile(Folderbis,filename);
end

filebis=regexprep(filebis,' ', '\\ ' );


%we write a list of files to delete from the datafabric

if exist(strcat(FAIMMS_DownloadFolder,'/log_ToDo'),'dir') == 0
    mkdir(strcat(FAIMMS_DownloadFolder,'/log_ToDo'));
end

switch level
    case 0
        Filename_ListFile2delete=fullfile(FAIMMS_DownloadFolder,strcat('log_ToDo/file2delete_RAW_',DATE_PROGRAM_LAUNCHED,'.txt'));
    case 1
        Filename_ListFile2delete=fullfile(FAIMMS_DownloadFolder,strcat('log_ToDo/file2delete_QAQC_',DATE_PROGRAM_LAUNCHED,'.txt'));
end

fid_ListFile2delete = fopen(Filename_ListFile2delete, 'a+');
fprintf(fid_ListFile2delete,'%s \n',filebis);
fclose(fid_ListFile2delete);