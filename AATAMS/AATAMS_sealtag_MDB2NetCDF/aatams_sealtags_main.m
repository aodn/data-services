function aatams_sealtags_main()
%aatams_sealtags_main - full process of aatams sealtags files
%this toolbox aims to convert CTD data from AATAMS stored as Microsoft
%Access Database (MDB) into NetCDF files.
%
%Many different requirements are essential to run this toolbox.
%1)having a local instance of a PostgreSQL database. 
%2)having created already a database called aatams 'CREATE DATABASE
%aatams;'
%3)having the java class  postgresql-9.1-902.jdbc4.jar in the MATLAB
%javapath, this has to be set up in startup.m
%4)mdbtools must be installed. sudo apt-get install mdbtools (on debian)
%5)python must be installed
%
%Files are first unzipped, converted into PostgreSQL scripts to load into
%the database. Tables are dropped each time this process runs. The tables
%are queried to get the data, then each profile is converted as a NetCDF
%files. All the profiles with a same WMO code are in a same folder of the
%WMO code's name. An aggregated file of all the profiles is created too.
%All temporary files/tables are deleted
%
%All the MDB files to process have to be zipped in the folder defined by
%DATA_FOLDER. 
%A new folder will be created called NETCDF where the processed files will
%be stored.
%
% Syntax:  createAATAMS_1profile_netcdf(CTD_DATA, METADATA)
%
% Inputs:
%   
%
% Outputs:
%    aatamsLog.txt (stored in DATA_FOLDER)
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
SCRIPT_FOLDER   = WhereAreScripts.path;
addpath(genpath(SCRIPT_FOLDER));

% Add any *.jar java library to the classpath. WANRING, this function
% clears all the global variables, so we have to call them again !! 
addJarToPath([SCRIPT_FOLDER filesep 'myJavaClasses'])
clear SCRIPT_FOLDER

global SCRIPT_FOLDER;
SCRIPT_FOLDER =WhereAreScripts.path;

global DATA_FOLDER;


%% data folder location
DATA_FOLDER=readConfig('dataAATAMS.path', 'config.txt','=');
mkpath(DATA_FOLDER);

%% set up local database information. this is used to load the converted mdb files into it. Maybe we should find another way to do it
localdatabase_information=struct;
localdatabase_information.server      =readConfig('serverLocal.address', 'config.txt','=');
localdatabase_information.dbName      =readConfig('serverLocal.database', 'config.txt','=');
localdatabase_information.port        =readConfig('serverLocal.port', 'config.txt','=');
localdatabase_information.user        =readConfig('serverLocal.user', 'config.txt','=');
localdatabase_information.schema_name =readConfig('serverLocal.schema', 'config.txt','=');


%% Log File
diary (strcat(DATA_FOLDER,filesep,readConfig('logFile.name', 'config.txt','=')));

% sealTag_zipFile=dir(strcat(DATA_FOLDER,filesep,'mdbFiles',filesep,'*.zip'));
sealTag_zipFile =textscan(readConfig('mdbAATAMS.name', 'config.txt','='),'%s','delimiter',',');
sealTag_zipFile =sealTag_zipFile{1};
sealTag_zipFile =sealTag_zipFile(~cellfun('isempty',sealTag_zipFile));

sealTag_zipFile_Path=strcat(DATA_FOLDER,filesep,'mdbFiles',filesep,sealTag_zipFile);

for iisealTag_zipFile=1:length(sealTag_zipFile)
    dropTable(localdatabase_information)%we delete all tables from localdatabase_information.dbName, schema 'public'
    
    echo system off
    %% unzip file
    fprintf('%s - Process file %s\n',datestr(now),char(sealTag_zipFile(iisealTag_zipFile)))
    sealTag_filename =char(sealTag_zipFile_Path(iisealTag_zipFile));
    commandStr       =['gunzip -c ' sealTag_filename ' > ' strcat(sealTag_filename(1:end-3),'mdb') ];
    system(commandStr) ;
    
    
    %% convert file into sql
    fprintf('%s - Convert MDB to PSQL\n',datestr(now))
    commandStr =['python ',SCRIPT_FOLDER,filesep,'subroutines/','mdb2psql.py ', strcat(sealTag_filename(1:end-3),'mdb'),'> ' ,strcat(sealTag_filename(1:end-3),'sql') ];
    system(commandStr) ;
    
    
    %% load into psql data
    fprintf('%s - Load file %s into local Database\n',datestr(now),char(sealTag_zipFile(iisealTag_zipFile)))
    commandStr=['psql -q -h localhost -U postgres -w -d aatams -f ',strcat(sealTag_filename(1:end-3),'sql'),...
        ';rm -f ',strcat(sealTag_filename(1:end-3),'sql'),...
        ';rm -f ',strcat(sealTag_filename(1:end-3),'mdb')];
    system(commandStr) ; % '-q' option avoids all the echo
    
   
     
    %% Query DB and create files
    [CTD_DATA, METADATA] =loadCTD_datafromDB(localdatabase_information);
    if ~(isempty(fieldnames(CTD_DATA)) | isempty(localdatabase_information))
        fprintf('%s - Create NetCDF profile\n',datestr(now))
        read_writeInfo(METADATA)
        createAATAMS_1profile_netcdf(CTD_DATA, METADATA)
    else
        fprintf('%s - WARNING: mdb file will not be processed\n',datestr(now))
    end
    dropTable(localdatabase_information)%we delete all tables from localdatabase_information.dbName, schema 'public'
    
    clear CTD_DATA METADATA
end

fprintf('%s - Remove bad profiles with bad Latitude/Longitude,North hemisphere ...\n',datestr(now))
cleanNetCDF

fprintf('%s - Aggregate NetCDF profile\n',datestr(now))
aggregateAATAMS

fprintf('%s - Create SQL script for geoserver\n',datestr(now))
writeSQL_inserts

diary 'off'

fprintf('%s - loading SQL script for geoserver\n',datestr(now))

commandStr =['psql -q -h localhost -U postgres -w -d maplayers -f ',strcat(SCRIPT_FOLDER,filesep,'subroutines/imos_database_sql', filesep,'createTables.sql')];
system(commandStr) ;

commandStr =['psql -q -h localhost -U postgres -w -d maplayers -f ',strcat(DATA_FOLDER,filesep,'DB_Insert_AATAMS_TABLE.sql')];
system(commandStr) ;

updateGeom
commandStr =['psql -q -h localhost -U postgres -w -d maplayers -f ',strcat(DATA_FOLDER,filesep,'DB_UPDATE_GEOM_AATAMS_TABLE.sql')];
system(commandStr) ; % '-q' option avoids all the echo

% remove blank space in database
commandStr =['psql -q -h localhost -U postgres -w -d maplayers -f ',strcat(SCRIPT_FOLDER,filesep,'subroutines/imos_database_sql', filesep, 'updateText.sql')];
system(commandStr) ;
% %% test good, we plot all profiles for one day for one tag and check with the website the plots are similar
% [a,b,c]=unique_no_sort({CTD_DATA.ref}');
% tagName=unique({CTD_DATA((c==1)).ref}')
% 
% idxDay=END_DATE_sorted>datenum(2011,03,13,00,00,00) & END_DATE_sorted<datenum(2011,03,13,23,59,00);
% nProfileDay=sum(idxDay)
% A=IX(idxDay);
% figure
% for iiDay=1:nProfileDay
%     profileIDX=A(iiDay);
%     datestr(END_DATE_sorted(iiProfileOrderedInTime));
%     N_TEMP=str2double({CTD_DATA(profileIDX).N_TEMP}');
%     TEMP_DBAR=({CTD_DATA(profileIDX).TEMP_DBAR}');
%     TEMP_VALS=({CTD_DATA(profileIDX).TEMP_VALS}');
%     TEMP_VALS_profile = cell2mat(textscan(TEMP_VALS{1},'%f', N_TEMP(1),'delimiter', ','));
%     TEMP_DBAR_profile = cell2mat(textscan(TEMP_DBAR{1},'%f', N_TEMP(1),'delimiter', ','));
%     plot (TEMP_VALS_profile,-TEMP_DBAR_profile)
%     hold all
% end