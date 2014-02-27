function DataFabricFileManagement(level)
%% DataFabricFileManagement
% This function reads the log files to know :
% 1)which channels need to be completely deleted from the datafabric (see
% also compareRSSwithPreviousInformationFAIMMS.m)
% 2)which files need to be copied to the datafabric
% 3)which files need to be deleted (see DeleteFile.m)
%
% Syntax:  DataFabricFileManagement
%
% Inputs: level        : double 0 or 1
%
%
% Outputs:
%
%
% Example:
%    DataFabricFileManagement(0)
%
% Other m-files required:
% Other files required:
% Subfunctions: none
% MAT-files required: none
%
% See also:FAIMMS_Launcher,compareRSSwithPreviousInformationFAIMMS,DeleteFile,
%          Move_File
%
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 24-Aug-2012

FAIMMS_DownloadFolder = readConfig('dataFAIMMS.path', 'config.txt','=');
DataFabricFolder = readConfig('df.path', 'config.txt','=');


switch level
    case 0
        LevelName='ARCHIVE';
        dirName='NO_QAQC';
        %         subDataFabricFolder=strcat(DataFabricFolder,'archive');
        
    case 1
        LevelName='QAQC';
        dirName='QAQC';
        %         subDataFabricFolder=strcat(DataFabricFolder,'opendap');
end

subDataFabricFolder=strcat(DataFabricFolder,filesep,'opendap');
newDateNow=strrep(datestr(now,'yyyymmdd_HHMMAM'),' ','');

if exist(strcat(FAIMMS_DownloadFolder,'/log_archive'),'dir') == 0
    mkdir(strcat(FAIMMS_DownloadFolder,'/log_archive'));
end

%% remove corrupted channel files and folder from DF
StatusErrorDeleteEntireChannelFolder=0;
LogFilesToRemoveCompletely=dir(fullfile(FAIMMS_DownloadFolder,strcat('log_ToDo/ChannelID_2removeCompletely_*')));
for tt=1:length(LogFilesToRemoveCompletely)
    if LogFilesToRemoveCompletely(tt).bytes~=0
        fidLogFilesToRemoveCompletely = fopen(fullfile(FAIMMS_DownloadFolder,'log_ToDo',LogFilesToRemoveCompletely(tt).name));
        
        kk=1;
        tline = fgetl(fidLogFilesToRemoveCompletely);
        while ischar(tline)
            Channel2Remove{kk}=tline;
            kk=kk+1;
            tline= fgetl(fidLogFilesToRemoveCompletely);
        end
        fclose(fidLogFilesToRemoveCompletely);
        
        StatusErrorDeleteEntireChannelFolder=0;
        for kk=1:length(Channel2Remove)
            if ~isempty(strrep(Channel2Remove{kk},' ',''))
                pathstr  = (strcat(subDataFabricFolder,'/FAIMMS/',Channel2Remove{kk}));
                [status]=rmdir(pathstr,'s');%for some reasons, this status is not really reliable. Have to check the folder still exist or not afterwards
                status=~(exist(pathstr,'dir')==7);
                if status==1
                    fprintf('%s - SUCCESS: FOLDER DELETED FROM DF "%s"\n',datestr(now),strcat(pathstr));
                elseif status==0
                    fprintf('%s - ERROR: FOLDER NOT DELETED FROM DF "%s"\n',datestr(now), strcat(pathstr));
                    StatusErrorDeleteEntireChannelFolder=StatusErrorDeleteEntireChannelFolder+1;
                    
                    %% we re-write a new file with the errors one only. the previous file will be moved.
                    fidLogFilesToRemoveCompletely_NEW = fopen(fullfile(FAIMMS_DownloadFolder,'log_ToDo',strcat('ChannelID_2removeCompletely_',newDateNow,'.txt')),'a+');
                    fprintf(fidLogFilesToRemoveCompletely_NEW,'%s\n',Channel2Remove{kk});
                    fclose(fidLogFilesToRemoveCompletely_NEW);
                    
                end
            end
        end
        
        if StatusErrorDeleteEntireChannelFolder == 0
            movefile(fullfile(FAIMMS_DownloadFolder,'log_ToDo',LogFilesToRemoveCompletely(tt).name),strcat(FAIMMS_DownloadFolder,'/log_archive'));
        else
            movefile(fullfile(FAIMMS_DownloadFolder,'log_ToDo',LogFilesToRemoveCompletely(tt).name),strcat(FAIMMS_DownloadFolder,'/log_archive'));
            fprintf('%s - ERROR: "%s" could to be check manually. Next try on next launch. ChannelID could not be completely deleted from DF\n',datestr(now),LogFilesToRemoveCompletely(tt).name)
        end
    else
        delete (fullfile(FAIMMS_DownloadFolder,strcat('log_ToDo/',LogFilesToRemoveCompletely(tt).name)))
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if StatusErrorDeleteEntireChannelFolder == 0
    %% Copy new files to the DF
    switch level
        case 0
            LogFilesToCopy=dir(fullfile(FAIMMS_DownloadFolder,strcat('log_ToDo/file2copy_RAW_*')));
            
        case 1
            LogFilesToCopy=dir(fullfile(FAIMMS_DownloadFolder,strcat('log_ToDo/file2copy_QAQC_*')));
    end
    
    % LogFilesToCopy=dir(fullfile(FAIMMS_DownloadFolder,strcat('log_ToDo/file2copy_*')));
    
    for tt=1:length(LogFilesToCopy)
        fid2 = fopen(fullfile(FAIMMS_DownloadFolder,'log_ToDo',LogFilesToCopy(tt).name));
        
        kk=1;
        tline = fgetl(fid2);
        while ischar(tline)
            FileTocopy{kk}=tline;
            kk=kk+1;
            tline= fgetl(fid2);
        end
        fclose(fid2);
        
        StatusError=0;
        for kk=1:length(FileTocopy)
            %% create the folder on the DF
            [pathstr,fileName,ext ] = fileparts(strcat(subDataFabricFolder,'/FAIMMS/',FileTocopy{kk}));
            pathstr=fullfile(pathstr,dirName);
            
            if exist(pathstr,'dir') == 0
                DirCreated=0;
                while ~DirCreated
                    DirCreated=mkdir(pathstr);
                end
            end
            
            [status] = movefile(strcat(FAIMMS_DownloadFolder,filesep,'sorted',filesep,LevelName,filesep,FileTocopy{kk}),strcat(pathstr,filesep,fileName,ext));
            
            if status==0
                StatusError=StatusError+1;
                fprintf('%s - ERROR:  COPY ACHIEVED TO THE DF:  NO --FILE: "%s"\n',datestr(now),strcat(pathstr,filesep,fileName,ext));
                
                %% we re-write a new file with the errors one only. the previous file will be moved.
                switch level
                    case 0
                        LogFilesToCopy_NEW=fullfile(FAIMMS_DownloadFolder,strcat('log_ToDo/file2copy_RAW_',newDateNow,'.txt'));
                        
                    case 1
                        LogFilesToCopy_NEW=fullfile(FAIMMS_DownloadFolder,strcat('log_ToDo/file2copy_QAQC_',newDateNow,'.txt'));
                end
                fid2_NEW = fopen(LogFilesToCopy_NEW,'a+');
                fprintf(fid2_NEW,'%s\n',FileTocopy{kk});
                fclose(fid2_NEW);
                
            elseif status==1
                fprintf('%s - SUCCESS:COPY ACHIEVED TO THE DF: YES --FILE: "%s"\n',datestr(now),strcat(pathstr,filesep,fileName,ext));
            end
        end
        
        if StatusError == 0
            movefile(fullfile(FAIMMS_DownloadFolder,'log_ToDo',LogFilesToCopy(tt).name),strcat(FAIMMS_DownloadFolder,'/log_archive'));
        else
            movefile(fullfile(FAIMMS_DownloadFolder,'log_ToDo',LogFilesToCopy(tt).name),strcat(FAIMMS_DownloadFolder,'/log_archive'));
            fprintf('%s - ERROR: "%s" has to be check manually,files could not be copied for some reasons\n',datestr(now),LogFilesToCopy(tt).name)
        end
    end
    
    %     %% For any reason if a file has not been copied to the DF, we'll try it again
    %     DownloadFolder=strcat(FAIMMS_DownloadFolder,'/sorted/',LevelName);
    %     [~,~,fileNames]=DIRR(DownloadFolder,'.nc','name','isdir','1');
    %
    %     for kk=1:length(fileNames)
    %
    %         %% check it's a file
    %         if strcmp(fileNames{kk}(end-2:end),'.nc')
    %             [pathstr, name, ext] = fileparts(fileNames{kk});
    %
    %             %% create the folder on the DF
    %             k=strfind(pathstr,LevelName);
    %             FileFolder=strcat(subDataFabricFolder,'/FAIMMS',pathstr(k+length(LevelName):end),filesep,dirName);
    %             if exist(FileFolder,'dir') == 0
    %                 DirCreated=0;%improve dir creation on df : Device or resource busy
    %                 while ~DirCreated
    %                     DirCreated=mkdir(FileFolder);
    %                 end
    %             end
    %
    %             %% move file to the DF
    %             [status]  = movefile(fileNames{kk},strcat(FileFolder,filesep,name,ext));
    %             if status==0
    %                 fprintf('%s - ERROR: NO COPY TO DF "%s"\n',datestr(now), fileNames{kk});
    %             end
    %         end
    %     end
    
    %% Remove old/dupicated files to the DF
    switch level
        case 0
            LogFilesToDelete=dir(fullfile(FAIMMS_DownloadFolder,strcat('log_ToDo/file2delete_RAW_*')));
            
        case 1
            LogFilesToDelete=dir(fullfile(FAIMMS_DownloadFolder,strcat('log_ToDo/file2delete_QAQC_*')));
    end
    
    for tt=1:length(LogFilesToDelete)
        try
            fid = fopen(fullfile(FAIMMS_DownloadFolder,'log_ToDo',LogFilesToDelete(tt).name));
            
            kk=1;
            tline = fgetl(fid);
            while ischar(tline)
                FileToDelete{kk}=tline;
                kk=kk+1;
                tline= fgetl(fid);
            end
            
            fclose(fid);
            
            SuccessBoolean=1;
            for kk=1:length(FileToDelete)
                %                 [pathstr,fileName,ext ] = fileparts(strcat(subDataFabricFolder,'/FAIMMS/',FileToDelete{kk}));
                [pathstr,fileName,ext ] = fileparts(FileToDelete{kk});
                fullpathstr=fullfile(subDataFabricFolder,'FAIMMS',pathstr,dirName);
                FileToDeleteSTR{kk}=strtrim(fullfile(fullpathstr,[fileName ext])); % remove the space if it is at the end of the filename. This causes a conflict otherwise
                
                if exist(FileToDeleteSTR{kk},'file')
                    delete(FileToDeleteSTR{kk})
                    if exist(FileToDeleteSTR{kk},'file')
                        fprintf('%s - ERROR: DELETE, STILL EXIST "%s"\n',datestr(now),FileToDeleteSTR{kk})
                        SuccessBoolean=0;
                        
                        %% we re-write a new file with the errors one only. the previous file will be moved.
                        switch level
                            case 0
                                LogFilesToDelete_NEW=fullfile(FAIMMS_DownloadFolder,strcat('log_ToDo/file2delete_RAW_',newDateNow,'.txt'));
                                
                            case 1
                                LogFilesToDelete_NEW=fullfile(FAIMMS_DownloadFolder,strcat('log_ToDo/file2delete_QAQC_',newDateNow,'.txt'));
                        end
                        fid_NEW = fopen(LogFilesToDelete_NEW,'a+');
                        fprintf(fid_NEW,'%s\n',FileToDelete{kk});
                        fclose(fid_NEW);
                    else
                        fprintf('%s - SUCCESS: DELETE "%s"\n',datestr(now),FileToDeleteSTR{kk})
                    end
                else
                    fprintf('%s - ERROR: DELETE NOT FOUND "%s"\n',datestr(now),FileToDeleteSTR{kk})
                    SuccessBoolean=0;
                    %% we re-write a new file with the errors one only. the previous file will be moved.
                    switch level
                        case 0
                            LogFilesToDelete_NEW=fullfile(FAIMMS_DownloadFolder,strcat('log_ToDo/file2delete_RAW_',newDateNow,'.txt'));
                            
                        case 1
                            LogFilesToDelete_NEW=fullfile(FAIMMS_DownloadFolder,strcat('log_ToDo/file2delete_QAQC_',newDateNow,'.txt'));
                    end
                    fid_NEW = fopen(LogFilesToDelete_NEW,'a+');
                    fprintf(fid_NEW,'%s\n',FileToDelete{kk});
                    fclose(fid_NEW);
                end
            end
            clear tline
            if SuccessBoolean
                % we move the file from ToDo because everything
                % succeed.Otherwise have to check it manually
                movefile(fullfile(FAIMMS_DownloadFolder,'log_ToDo',LogFilesToDelete(tt).name),strcat(FAIMMS_DownloadFolder,'/log_archive'));
            else
                movefile(fullfile(FAIMMS_DownloadFolder,'log_ToDo',LogFilesToDelete(tt).name),strcat(FAIMMS_DownloadFolder,'/log_archive'));
                fprintf('%s - ERROR "%s" has to be check manually,files could not be deleted for some reasons\n',datestr(now),LogFilesToDelete(tt).name)
            end
            
        catch
            fprintf('%s - No files to delete From the DF\n',datestr(now))
        end
    end
else
    fprintf('%s - Some folders could not be deleted. Nothing is copied then onto the datafabric prior this is checked manually\n',datestr(now))
end