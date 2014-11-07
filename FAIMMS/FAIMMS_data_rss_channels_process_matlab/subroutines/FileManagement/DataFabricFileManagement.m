function DataFileManagement(levelQC)
%% DataFabricFileManagement
% This function reads the log files to know :
% 1)which channels need to be completely deleted from the datafabric (see
% also compareRSSwithPreviousInformationFAIMMS.m)
% 2)which files need to be copied to the datafabric
% 3)which files need to be deleted (see DeleteFile.m)
%
% Syntax:  DataFileManagement
%
% Inputs: levelQC        : double 0 or 1
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


dataWIP          = readConfig('dataWIP.path', 'config.txt','=');
dataOpendapRsync = readConfig('dataOpendapRsync.path', 'config.txt','=');

switch levelQC
    case 0
        levelQCName    ='ARCHIVE';
        levelQCDirName ='NO_QAQC';
        
    case 1
        levelQCName    ='QAQC';
        levelQCDirName ='QAQC';
end

subDataFabricFolder = strcat(dataOpendapRsync,filesep,'opendap');
dateNow             = strrep(datestr(now,'yyyymmdd_HHMMAM'),' ','');

if exist(strcat(dataWIP,'/log_archive'),'dir') == 0
    mkpath(strcat(dataWIP,'/log_archive'));
end

%% remove corrupted channel files and folder
StatusErrorDeleteEntireChannelFolder = 0;
LogFilesToRemoveCompletely           = dir(fullfile(dataWIP,strcat('log_ToDo/ChannelID_2removeCompletely_*')));
for tt=1:length(LogFilesToRemoveCompletely)
    if LogFilesToRemoveCompletely(tt).bytes~=0
        fidLogFilesToRemoveCompletely = fopen(fullfile(dataWIP,'log_ToDo',LogFilesToRemoveCompletely(tt).name));
        
        kk                            = 1;
        tline                         = fgetl(fidLogFilesToRemoveCompletely);
        while ischar(tline)
            Channel2Remove{kk} = tline;
            kk                 = kk+1;
            tline              = fgetl(fidLogFilesToRemoveCompletely);
        end
        fclose(fidLogFilesToRemoveCompletely);
        
        StatusErrorDeleteEntireChannelFolder=0;
        for kk=1:length(Channel2Remove)
            if ~isempty(strrep(Channel2Remove{kk},' ',''))
                pathstr  = (strcat(subDataFabricFolder,filesep,Channel2Remove{kk}));
                [status] =rmdir(pathstr,'s');%for some reasons, this status is not really reliable. Have to check the folder still exist or not afterwards
                status   =~(exist(pathstr,'dir')==7);
                if status == 1
                    fprintf('%s - SUCCESS: FOLDER DELETED "%s"\n',datestr(now),strcat(pathstr));
                elseif status == 0
                    fprintf('%s - ERROR: FOLDER NOT DELETED "%s"\n',datestr(now), strcat(pathstr));
                    StatusErrorDeleteEntireChannelFolder = StatusErrorDeleteEntireChannelFolder+1;
                    
                    %% we re-write a new file with the errors one only. the previous file will be moved.
                    fidLogFilesToRemoveCompletely_NEW    = fopen(fullfile(dataWIP,'log_ToDo',strcat('ChannelID_2removeCompletely_',dateNow,'.txt')),'a+');
                    fprintf(fidLogFilesToRemoveCompletely_NEW,'%s\n',Channel2Remove{kk});
                    fclose(fidLogFilesToRemoveCompletely_NEW);
                    
                end
            end
        end
        
        if StatusErrorDeleteEntireChannelFolder == 0
            movefile(fullfile(dataWIP,'log_ToDo',LogFilesToRemoveCompletely(tt).name),strcat(dataWIP,'/log_archive'));
        else
            movefile(fullfile(dataWIP,'log_ToDo',LogFilesToRemoveCompletely(tt).name),strcat(dataWIP,'/log_archive'));
            fprintf('%s - ERROR: "%s" could to be check manually. Next try on next launch. ChannelID could not be completely deleted \n',datestr(now),LogFilesToRemoveCompletely(tt).name)
        end
    else
        delete (fullfile(dataWIP,strcat('log_ToDo/',LogFilesToRemoveCompletely(tt).name)))
    end
end

%% Copy new files
if StatusErrorDeleteEntireChannelFolder == 0    
    switch levelQC
        case 0
            LogFilesToCopy = dir(fullfile(dataWIP,strcat('log_ToDo/file2copy_RAW_*')));
            
        case 1
            LogFilesToCopy = dir(fullfile(dataWIP,strcat('log_ToDo/file2copy_QAQC_*')));
    end
    
    
    for tt = 1:length(LogFilesToCopy)
        fid_LogFilesToCopy = fopen(fullfile(dataWIP,'log_ToDo',LogFilesToCopy(tt).name));
        
        kk                 = 1;
        tline              = fgetl(fid_LogFilesToCopy);
        while ischar(tline)
            FileTocopy{kk} = tline;
            kk             = kk+1;
            tline          = fgetl(fid_LogFilesToCopy);
        end
        fclose(fid_LogFilesToCopy);
        
        StatusError=0;
        for kk=1:length(FileTocopy)
            %% create the folder
            [pathstr,fileName,ext ] = fileparts(strcat(subDataFabricFolder,filesep,FileTocopy{kk}));
            pathstr                 =fullfile(pathstr,levelQCDirName);
            
            if exist(pathstr,'dir') == 0
                mkpath(pathstr);
            end
            
            if exist(strcat(dataWIP,filesep,'sorted',filesep,levelQCName,filesep,FileTocopy{kk}),'file') == 2
                [status] = movefile(strcat(dataWIP,filesep,'sorted',filesep,levelQCName,filesep,FileTocopy{kk}),strcat(pathstr,filesep,fileName,ext));
                
                
                if status == 0
                    StatusError=StatusError+1;
                    
                    % check if the file already exists in the destination folder
                    if exist(strcat(pathstr,filesep,fileName,ext),'file') == 2
                        fprintf('%s - WARNING:  COPY ACHIEVED PREVIOUSLY --FILE: "%s"\n',datestr(now),strcat(pathstr,filesep,fileName,ext));
                        delete(strcat(dataWIP,filesep,'sorted',filesep,levelQCName,filesep,FileTocopy{kk}))
                    else
                        % we need to check if a new version of a the same file
                        % exist (ie, a file with the same start date, but a
                        % different end date)
                        [firstDate_alreadyCopied,lastDate_alreadyCopied,creationDate_alreadyCopied,ncFile_alreadyCopied] = listAIMSfile_folder(pathstr);
                        [ firstDate_toCopy,lastDate_toCopy,creationDate_toCopy ]                                         = AIMS_fileDates( fileName);
                        
                        %conditions unlikely to happen. but who knaws. My code
                        %may have some random features
                        rewriteLog = 1;
                        if lastDate_toCopy(firstDate_toCopy == firstDate_alreadyCopied) < lastDate_alreadyCopied(firstDate_toCopy == firstDate_alreadyCopied)
                            % new file doesn't have the newest data, we should
                            % delete it and not copy it
                            delete(strcat(dataWIP,filesep,'sorted',filesep,levelQCName,filesep,FileTocopy{kk}))
                            rewriteLog = 0;
                        elseif lastDate_toCopy(firstDate_toCopy == firstDate_alreadyCopied) > lastDate_alreadyCopied(firstDate_toCopy == firstDate_alreadyCopied)
                            % this condition shouldn't happend
                        elseif lastDate_toCopy(firstDate_toCopy == firstDate_alreadyCopied) == lastDate_alreadyCopied(firstDate_toCopy == firstDate_alreadyCopied)
                            % file is alreay there, we can delete it from the
                            % temp folder
                            delete(strcat(dataWIP,filesep,'sorted',filesep,levelQCName,filesep,FileTocopy{kk}))
                            rewriteLog = 0;
                        end
                        
                        %%%%%%%%%%
                        if rewriteLog == 1
                            fprintf('%s - ERROR:  COPY ACHIEVED :  NO --FILE: "%s"\n',datestr(now),strcat(pathstr,filesep,fileName,ext));
                            
                            %% we re-write a new log file with the errors one only. the previous log file will be moved.
                            switch levelQC
                                case 0
                                    LogFilesToCopy_NEW = fullfile(dataWIP,strcat('log_ToDo/file2copy_RAW_',dateNow,'.txt'));
                                    
                                case 1
                                    LogFilesToCopy_NEW = fullfile(dataWIP,strcat('log_ToDo/file2copy_QAQC_',dateNow,'.txt'));
                            end
                            fid2_NEW = fopen(LogFilesToCopy_NEW,'a+');
                            fprintf(fid2_NEW,'%s\n',FileTocopy{kk});
                            fclose(fid2_NEW);
                        elseif rewriteLog == 0
                             fprintf('%s - WARNING:  SIMILAR FILE ALREADY EXIST : --FILE: "%s"\n',datestr(now),strcat(pathstr,filesep,fileName,ext));

                            
                        end
                    end
                elseif status==1
                    fprintf('%s - SUCCESS:COPY ACHIEVED : YES --FILE: "%s"\n',datestr(now),strcat(pathstr,filesep,fileName,ext));
                end
            end
        end
        
        if StatusError == 0
            movefile(fullfile(dataWIP,'log_ToDo',LogFilesToCopy(tt).name),strcat(dataWIP,'/log_archive'));
        else
            movefile(fullfile(dataWIP,'log_ToDo',LogFilesToCopy(tt).name),strcat(dataWIP,'/log_archive'));
            fprintf('%s - ERROR: "%s" has to be check manually,files could not be copied for some reasons\n',datestr(now),LogFilesToCopy(tt).name)
        end
    end
    
  
    
    %% Remove old/dupicated files 
    switch levelQC
        case 0
            LogFilesToDelete = dir(fullfile(dataWIP,strcat('log_ToDo/file2delete_RAW_*')));
            
        case 1
            LogFilesToDelete = dir(fullfile(dataWIP,strcat('log_ToDo/file2delete_QAQC_*')));
    end
    
    for tt=1:length(LogFilesToDelete)
        try
            fid = fopen(fullfile(dataWIP,'log_ToDo',LogFilesToDelete(tt).name));
            
            kk=1;
            tline = fgetl(fid);
            while ischar(tline)
                FileToDelete{kk} = tline;
                kk               = kk+1;
                tline            = fgetl(fid);
            end
            
            fclose(fid);
            
            SuccessBoolean=1;
            for kk=1:length(FileToDelete)
                [pathstr,fileName,ext ] = fileparts(FileToDelete{kk});
                fullpathstr             = fullfile(subDataFabricFolder,pathstr,levelQCDirName);
                FileToDeleteSTR{kk}     = strtrim(fullfile(fullpathstr,[fileName ext])); % remove the space if it is at the end of the filename. This causes a conflict otherwise
                
                if exist(FileToDeleteSTR{kk},'file')
                    delete(FileToDeleteSTR{kk})
                    if exist(FileToDeleteSTR{kk},'file')
                        fprintf('%s - ERROR: DELETE, STILL EXIST "%s"\n',datestr(now),FileToDeleteSTR{kk})
                        SuccessBoolean=0;
                        
                        %% we re-write a new file with the errors one only. the previous file will be moved.
                        switch levelQC
                            case 0
                                LogFilesToDelete_NEW = fullfile(dataWIP,strcat('log_ToDo/file2delete_RAW_',dateNow,'.txt'));
                                
                            case 1
                                LogFilesToDelete_NEW = fullfile(dataWIP,strcat('log_ToDo/file2delete_QAQC_',dateNow,'.txt'));
                        end
                        fid_NEW = fopen(LogFilesToDelete_NEW,'a+');
                        fprintf(fid_NEW,'%s\n',FileToDelete{kk});
                        fclose(fid_NEW);
                    else
                        fprintf('%s - SUCCESS: DELETE "%s"\n',datestr(now),FileToDeleteSTR{kk})
                    end
                else
%                     fprintf('%s - ERROR: DELETE NOT FOUND "%s"\n',datestr(now),FileToDeleteSTR{kk})
                    SuccessBoolean=0;
                    %% we re-write a new file with the errors one only. the previous file will be moved.
                    switch levelQC
                        case 0
                            LogFilesToDelete_NEW = fullfile(dataWIP,strcat('log_ToDo/file2delete_RAW_',dateNow,'.txt'));
                            
                        case 1
                            LogFilesToDelete_NEW = fullfile(dataWIP,strcat('log_ToDo/file2delete_QAQC_',dateNow,'.txt'));
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
                movefile(fullfile(dataWIP,'log_ToDo',LogFilesToDelete(tt).name),strcat(dataWIP,'/log_archive'));
            else
                movefile(fullfile(dataWIP,'log_ToDo',LogFilesToDelete(tt).name),strcat(dataWIP,'/log_archive'));
                fprintf('%s - ERROR "%s" has to be check manually,files could not be deleted for some reasons\n',datestr(now),LogFilesToDelete(tt).name)
            end
            
        catch
            fprintf('%s - No files to delete\n',datestr(now))
        end
    end
else
    fprintf('%s - Some folders could not be deleted. Nothing is copied. Check manually\n',datestr(now))
end