function aatams_sealtags_main()
%aatams_sealtags_main - full process of aatams sealtags files
%this toolbox aims to convert CTD data from AATAMS stored as Microsoft
%Access Database (MDB) into NetCDF files.
%
% different requirements are essential to run this toolbox.
%1)having sqlite3  install
%2)having created already a database called aatams 'CREATE DATABASE
%aatams;'
%3)having the java class  postgresql-9.1-902.jdbc4.jar in the MATLAB
%javapath, this has to be set up in startup.m
%
% All the profiles with a same WMO code are in a same folder of the
%WMO code's name. An aggregated file of all the profiles is created too.
%All temporary files/tables are deleted
%A new folder will be created called NETCDF where the processed files will
%be stored.
%
% Syntax:
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
dataWIP_Path  = readConfig('dataWIP.path', 'config.txt','=');
dataInputPath = readConfig('dataInput.path', 'config.txt','=');
javaPath      = readConfig('java.path', 'config.txt','=');

mkpath(dataWIP_Path);
%% Log File
diary (strcat(dataWIP_Path,filesep,readConfig('logFile.name', 'config.txt','=')));
mdbFiles = dir(strcat(dataInputPath,filesep,'*.mdb'));

for iiMDB = 1:length(mdbFiles)
    
    mdbFileToProcess = char(mdbFiles(iiMDB).name);
    aatams_mdb2nc(mdbFileToProcess)
    
end

diary 'off'

    function aatams_mdb2nc(mdbFileToProcess)
        sqliteFile = tempname ;
        %% convert file into sqlite
        fprintf('%s - Process %s\n',datestr(now), mdbFileToProcess)
        commandStr = [javaPath ' -jar myJavaClasses/mdb-sqlite-1.0.2/dist/mdb-sqlite.jar ' strcat(dataInputPath,filesep,mdbFileToProcess) ' ' sqliteFile ];
        system(commandStr) ;
        
        %% Query SQLITE and create files
        [CTD_DATA, METADATA] = loadCTD_datafromDB(sqliteFile);
        if ~(isempty(fieldnames(CTD_DATA)))
            read_writeInfo(METADATA)
            createAATAMS_Netcdf(CTD_DATA, METADATA)
        else
            fprintf('%s - WARNING: mdb file will not be processed\n',datestr(now))
        end
        
        clear CTD_DATA METADATA
        delete(sqliteFile)
    end

end

