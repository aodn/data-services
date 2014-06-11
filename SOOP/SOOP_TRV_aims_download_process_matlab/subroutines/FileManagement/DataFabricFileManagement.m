function [PATH_file]=DataFabricFileManagement(level)
global SOOP_DownloadFolder;
global DataFabricFolder;

switch level
    case 0
        LevelName='ARCHIVE';
    case 1
        LevelName='QAQC';
end

DownloadFolder=strcat(SOOP_DownloadFolder,'/sorted/',LevelName);


[~,~,fileNames]=DIRR(DownloadFolder,'.nc','name','isdir','1');

ii=1;
PATH_file_pre=[];
for kk=1:length(fileNames)
    
    %% check it's a file
    if strcmp(fileNames{kk}(end-2:end),'.nc')
        [pathstr, name, ext] = fileparts(fileNames{kk});
        PATH_file_pre{ii}=pathstr(length(DownloadFolder)+1:end); % used to tell which new folder has been created in opendap
        %% create the folder on the DF
        k=strfind(pathstr,LevelName);
        
        switch level
            case 0
                FileFolder=strcat(DataFabricFolder,filesep,'archive',filesep,'SOOP',pathstr(k+4:end));
            case 1
                FileFolder=strcat(DataFabricFolder,filesep,'opendap',filesep,'SOOP',pathstr(k+4:end));
        end
        
        if exist(FileFolder,'dir') == 0
            mkdir(FileFolder);
        end
        
        %% move file to the DF
        [status]  = movefile(fileNames{kk},strcat(FileFolder,filesep,name,ext));
        if status==0
            fprintf('%s - ERROR:   COPY ACHIEVED TO THE DF:  NO --FILE: %s\n',datestr(now), fileNames{kk});
        elseif status==1
            fprintf('%s - SUCCESS: COPY ACHIEVED TO THE DF: YES --FILE: %s\n',datestr(now), fileNames{kk});
        end
        
    end
end

PATH_file=unique(PATH_file_pre);