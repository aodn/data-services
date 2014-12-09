function aatams_sattags_dm_main(varargin)
%aatams_sealtags_main - full process of aatams sealtags files
%this toolbox aims to convert CTD data from AATAMS stored as Microsoft
%Access Database (MDB) into NetCDF files.
%
% Individual profiles as well as an aggregated file per PTT code are also created
%
% Requirements
% 1) sqlite3
% 2) java
%
% the mdb-sqlite jar was recompiled (ant clean;ant dist;) after adding a
% few patches : see
% https://code.google.com/p/mdb-sqlite/issues/detail?id=11
% https://code.google.com/p/mdb-sqlite/issues/detail?id=1
%
%
% Syntax: aatams_sattags_dm_main();
%         aatams_sattags_dm_main('force_reprocess_all')
%
% Inputs:
%
%
% Outputs:
%    aatamsLog.txt (stored in dataWIP_Path)
%
% Example:
%    aatams_sealtags_main
%
% Other m-files
% required:mkpath,loadCTD_datafromDB,createAATAMS_1profile_netcdf,dropTable
% Other files required: mdb2psql.py ,psql
% Subfunctions: none
% MAT-files required: none
%
% See also: loadCTD_datafromDB,createAATAMS_1profile_netcdf,aggregateAATAMS
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 09-Aug-2012

%% script location
WhereAreScripts = what;
scriptPath      = WhereAreScripts.path;
addpath(genpath(scriptPath));

% Add any *.jar java library to the classpath. WANRING, this function
% clears all the global variables, so we have to call them again !!
addJarToPath([scriptPath filesep 'myJavaClasses'])


%% data folder location output
dataWIP_Path        = readConfig('dataWIP.path', 'config.txt','=');
dataInputPath       = readConfig('dataInput.path', 'config.txt','=');
javaPath            = readConfig('java.path', 'config.txt','=');
mkpath(dataWIP_Path);

%% Optional function argument to force the reprocess of all files
nVarargs = size(varargin,2); 
if nVarargs > 0
    if strcmp ( varargin{1} ,'force_reprocess_all')       
        matFileSha1sum      = strcat(dataWIP_Path,filesep,'sha1sumLog.mat');
        if exist(matFileSha1sum,'file') == 2
            delete(matFileSha1sum,'-mat')            
        end        
    else
        warning('Wrong optional input')
    end    
end


%% Log File
diary (strcat(dataWIP_Path,filesep,readConfig('logFile.name', 'config.txt','=')));

mdbFiles          = dir(strcat(dataInputPath,filesep,'*.mdb'));
australianTagsFile  = readConfig('australianTags.filepath', 'config.txt','=');
sha1sum_csvFile_now = checksum(australianTagsFile);

% we load a mat file containing information regarding the MDB files already
% processed. The name as well as the checksum of the file is loading into
% the workspace
matFileSha1sum      = strcat(dataWIP_Path,filesep,'sha1sumLog.mat');
if exist(matFileSha1sum,'file') == 2
    load(matFileSha1sum,'-mat')
else
    mdb_alreadyProcessed           = repmat({''},1,length(mdbFiles)); %cell(1,length(mdbFiles));
    sha1sum_mdb_alreadyProcessed   = repmat({''},1,length(mdbFiles));
    sha1sum_csvFile_previousRun    = sha1sum_csvFile_now;
end
% if the CSV file is modified, we dont really bother, and reprocess
% everything. since anything could be modified, important or non important.
% it is simpler to debug, to code and only takes 2 hours to reprocess
% everything again.
isCSVFileModified = ~strcmp(sha1sum_csvFile_now ,sha1sum_csvFile_previousRun);

for iiMDB = 1:length(mdbFiles)
    
    mdbFileToProcess        = char(mdbFiles(iiMDB).name);
    sha1sum_mdbFile_now     = checksum( strcat(dataInputPath,filesep,mdbFileToProcess));
    
    isAlreadyProcessedIndex = find(ismember(mdb_alreadyProcessed,mdbFileToProcess));
    
    
    
    if ~isempty(isAlreadyProcessedIndex)
        isMDBFileModified    = ~strcmp(sha1sum_mdbFile_now , sha1sum_mdb_alreadyProcessed{isAlreadyProcessedIndex});
        if (isMDBFileModified || isCSVFileModified)
            % only process the file in the case either the CSV file
            % containing all the metadata has changed, either the mdb file
            % has changed. aatams_mdb2nc will delete/overwrite the nc already created
            
            aatams_mdb2nc(mdbFileToProcess);
            
            % replace the old values with the new ones
            mdb_alreadyProcessed{isAlreadyProcessedIndex}         = mdbFileToProcess;
            sha1sum_mdb_alreadyProcessed{isAlreadyProcessedIndex} = sha1sum_mdbFile_now;
            
            mdb_alreadyProcessed           = mdb_alreadyProcessed(~cellfun('isempty',mdb_alreadyProcessed))  ;
            sha1sum_mdb_alreadyProcessed   = sha1sum_mdb_alreadyProcessed(~cellfun('isempty',sha1sum_mdb_alreadyProcessed))  ;
            
            save (matFileSha1sum,'mdb_alreadyProcessed','sha1sum_mdb_alreadyProcessed','sha1sum_csvFile_previousRun')
        end
    else % mdb file never processed
        aatams_mdb2nc(mdbFileToProcess);
        
        mdb_alreadyProcessed{end+1}         = mdbFileToProcess;
        sha1sum_mdb_alreadyProcessed{end+1} = sha1sum_mdbFile_now;
        
        mdb_alreadyProcessed                = mdb_alreadyProcessed(~cellfun('isempty',mdb_alreadyProcessed))  ;
        sha1sum_mdb_alreadyProcessed        = sha1sum_mdb_alreadyProcessed(~cellfun('isempty',sha1sum_mdb_alreadyProcessed))  ;
         
        save (matFileSha1sum,'mdb_alreadyProcessed','sha1sum_mdb_alreadyProcessed','sha1sum_csvFile_previousRun')
    end
    
end

diary 'off'

    function  aatams_mdb2nc(mdbFileToProcess)
        sqliteFile           = tempname ;
        %% convert file into sqlite
        fprintf('%s - Process %s\n',datestr(now), mdbFileToProcess)
        commandStr           = [javaPath ' -jar myJavaClasses/mdb-sqlite-1.0.2/dist/mdb-sqlite.jar ' strcat(dataInputPath,filesep,mdbFileToProcess) ' ' sqliteFile ];
        system(commandStr) ;
        
        %% Query SQLITE and create files
        [CTD_DATA, METADATA] = loadCTD_datafromDB(sqliteFile);
        
        if ~(isempty(fieldnames(CTD_DATA)))
            createAATAMS_Netcdf(CTD_DATA, METADATA);
        else
            fprintf('%s - WARNING: mdb file will not be processed\n',datestr(now))
        end
        
        clear CTD_DATA METADATA
        delete(sqliteFile)
    end

end
