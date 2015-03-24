function rewriteLog(level)
%% rewriteLog
% This function rewrites the log files to keep only the unique lines. This
% is done because when the datafabric happens to be slow, or down, all the
% VM might freezes. We end up sometimes with those log files being enormous
% because many lines are repeated. For example, a log files was once 300mb,
% and once re-written, it was only 300ko.
% The function appends as well all the log files of a same kind into one.
% but when this function is called, there should be alway only one file of
% a kind.
%
% Syntax:  rewriteLog
%
% Inputs: level        : double 0 or 1 ( RAW, QAQC)
%
%
% Outputs:
%
%
% Example:
%    rewriteLog(0)
%
% Other m-files required:
% Other files required:
% Subfunctions: none
% MAT-files required: none
%
% See also: DataFileManagement,NRS_Launcher
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 01-Oct-2012
dataWIP = getenv('data_wip_path');

switch level
    case 0
        LevelName='ARCHIVE';
        dirName='NO_QAQC';

    case 1
        LevelName='QAQC';
        dirName='QAQC';
end

newDateNow=strrep(datestr(now,'yyyymmdd_HHMMAM'),' ','');

if exist(strcat(dataWIP,'/log_archive'),'dir') == 0
    mkdir(strcat(dataWIP,'/log_archive'));
end

%% log file2copy to rewrite
switch level
    case 0
        LogFilesToCopy=dir(fullfile(dataWIP,strcat('log_ToDo/file2copy_RAW_*')));

    case 1
        LogFilesToCopy=dir(fullfile(dataWIP,strcat('log_ToDo/file2copy_QAQC_*')));
end

for tt=1:length(LogFilesToCopy)
    fid2 = fopen(fullfile(dataWIP,'log_ToDo',LogFilesToCopy(tt).name));

    kk=1;
    tline = fgetl(fid2);
    while ischar(tline)
        FileTocopy{kk}=tline;
        kk=kk+1;
        tline= fgetl(fid2);
    end
    fclose(fid2);

    FileTocopyBis = unique(FileTocopy);

    %if size(FileTocopyBis,2)<size(FileTocopy,2)
        switch level
            case 0
                newFileName='file2copy_RAW_';

            case 1
                newFileName='file2copy_QAQC_';
        end
        %we rewrite the log file
        fidLogFilesToCopy_NEW = fopen(fullfile(dataWIP,'log_ToDo',strcat(newFileName,newDateNow,'.txt')),'a+');
        for kk=1:length(FileTocopyBis)
            fprintf(fidLogFilesToCopy_NEW,'%s\n',FileTocopyBis{kk});
        end
        fclose(fidLogFilesToCopy_NEW);
        movefile(fullfile(dataWIP,'log_ToDo',LogFilesToCopy(tt).name),strcat(dataWIP,'/log_archive'));

    %end
end



%% log file2delete to rewrite
switch level
    case 0
        LogFilesToDelete=dir(fullfile(dataWIP,strcat('log_ToDo/file2delete_RAW_*')));

    case 1
        LogFilesToDelete=dir(fullfile(dataWIP,strcat('log_ToDo/file2delete_QAQC_*')));
end

for tt=1:length(LogFilesToDelete)
    fid2 = fopen(fullfile(dataWIP,'log_ToDo',LogFilesToDelete(tt).name));

    kk=1;
    tline = fgetl(fid2);
    while ischar(tline)
        FileTodelete{kk}=tline;
        kk=kk+1;
        tline= fgetl(fid2);
    end
    fclose(fid2);

    FileTodeleteBis = unique(FileTodelete);

    %if size(FileTodeleteBis,2)<size(FileTodelete,2)
        switch level
            case 0
                newFileName='file2delete_RAW_';

            case 1
                newFileName='file2delete_QAQC_';
        end
        %we rewrite the log file
        fidLogFilesToDelete_NEW = fopen(fullfile(dataWIP,'log_ToDo',strcat(newFileName,newDateNow,'.txt')),'a+');
        for kk=1:length(FileTodeleteBis)
            fprintf(fidLogFilesToDelete_NEW,'%s\n',FileTodeleteBis{kk});
        end
        fclose(fidLogFilesToDelete_NEW);
        movefile(fullfile(dataWIP,'log_ToDo',LogFilesToDelete(tt).name),strcat(dataWIP,'/log_archive'));

    %end
end