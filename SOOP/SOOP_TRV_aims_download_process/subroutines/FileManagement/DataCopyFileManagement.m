function [PATH_file]=DataCopyFileManagement(level)
global dataWIP;
global destinationPath;

switch level
    case 0
        LevelName = 'ARCHIVE';
    case 1
        LevelName = 'QAQC';
end

DownloadFolder  = strcat(dataWIP,filesep,'sorted',filesep,LevelName,filesep,'SOOP-TRV');


[~,~,fileNames] = DIRR(DownloadFolder,'.nc','name','isdir','1');

ii=1;
file_relative_path=[];
for kk=1:length(fileNames)

    %% check it's a file
    if strcmp(fileNames{kk}(end-2:end),'.nc')
        [pathstr, filename, ext] = fileparts(fileNames{kk});
        file_relative_path{ii}   =pathstr(length(DownloadFolder)+2:end); % used to tell which new folder has been created in opendap

        switch level
            case 0

            case 1
                file_full_path = strcat(destinationPath,filesep,file_relative_path{ii});
        end

        if exist(file_full_path,'dir') == 0
            mkdir(file_full_path);
        end

        %% move file to the DF
        [status]  = movefile(fileNames{kk},strcat(file_full_path,filesep,filename,ext));
        if status==0
            fprintf('%s - ERROR  :  COPY -FILE: %s\n',datestr(now), fileNames{kk});
        elseif status==1
            fprintf('%s - SUCCESS: COPY -FILE: %s\n',datestr(now), fileNames{kk});
        end

    end
end

PATH_file = unique(file_relative_path);