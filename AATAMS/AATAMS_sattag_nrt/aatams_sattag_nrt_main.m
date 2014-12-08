function aatams_sealtags_nrt_main
% Process Near Real Time files from ATTAMS
%% script location
WhereAreScripts = what;
scriptPath      = WhereAreScripts.path;
addpath(genpath(scriptPath));


%% data folder location output
dataWIP_Path  = readConfig('dataWIP.path', 'config.txt','=');
dataInputPath = readConfig('dataInput.path', 'config.txt','=');
mkpath(dataWIP_Path);

%% Listing of all the input files available in the input directory
datFiles             = dir(strcat(dataInputPath,filesep,'*.dat'));
nDatFiles            = length(datFiles);

%% Log File
diary (strcat(dataWIP_Path,filesep,readConfig('logFile.name', 'config.txt','=')));

%% ACCESS the log files of the files already processed by MATLAB
aatamsTagLogFile         = strcat(dataWIP_Path,filesep, 'AATAMS_TAGS_LOGS_matlab_processing.txt');
if exist(aatamsTagLogFile) == 2
    fid                      = fopen(aatamsTagLogFile,'r');
    line                     = fgetl(fid);
    filesAlreadyProcessed{1} = line ;
    
    i = 2;
    while line ~= -1,
        line                     = fgetl(fid);
        filesAlreadyProcessed{i} = line ;
        i                        = i+1;
    end
    nbinputprocessed = length(filesAlreadyProcessed)-1;
    fclose(fid);
else
    filesAlreadyProcessed = cell(0);
    nbinputprocessed =0;
end

%% Creation of the list of files to process
k = 1;
isFilesBeenProcessed = 0;
for i = 1:nDatFiles
    if (nbinputprocessed)
        for j = 1:nbinputprocessed
            if (datFiles(i).name == filesAlreadyProcessed{j})
                isFilesBeenProcessed = isFilesBeenProcessed +1;
            end
        end
        if (~isFilesBeenProcessed)
            filesToProcess{k} = datFiles(i).name;
            k=k+1;
        end
        isFilesBeenProcessed = 0;
    else
        filesToProcess{k} = datFiles(i).name;
        k=k+1;
        isFilesBeenProcessed = 0;
    end
end





%% process each dat file. many *.dat  for one Q* folder
if exist('filesToProcess','var')
    nbfiles2process = length(filesToProcess);
    fid_w = fopen(aatamsTagLogFile,'a+');
    for zz = 1:nbfiles2process
        datFileToProcess = strcat(dataInputPath,filesep,filesToProcess{zz});
        fprintf('%s - Processing %s \n',datestr(now),filesToProcess{zz})
        
        tagProcessed{zz} = aatamsProcessDat(datFileToProcess);
        fprintf(fid_w,'%s\r\n',filesToProcess{zz});
    end
    fclose(fid_w);
    
    
    %% if new dat files
    tagProcessedUnique = findUniqueTagsProcessed(tagProcessed);
    for jj = 1 : length(tagProcessedUnique)
        AATAMS_seals_aggregation_profiles(char(tagProcessedUnique(jj)))
    end
else
        fprintf('%s - No Files to process \n',datestr(now))

end
end

function [tagProcessedUnique] =  findUniqueTagsProcessed(tagProcessed)
j = 0 ;
for ii = 1 : length(tagProcessed)
    if ~isempty( tagProcessed{ii})
        for kk = 1 : length(tagProcessed{ii})
            j = j+1;            
            new{j} = (tagProcessed{ii}{kk});
        end
    end
end
tagProcessedUnique = unique(new);
end
