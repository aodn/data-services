function [CTD_DATA, METADATA] =loadCTD_datafromDB(sqliteFile)
%loadCTD_datafromDB - load data and metadata from postgres database.
%
% Syntax:  createAATAMS_1profile_netcdf(CTD_DATA, METADATA)
%
% Inputs:
%    sqliteFile - structure of information about user,server,port
%
% Outputs:
%    CTD_DATA - structure of data
%    METADATA - structure of metadata
%
% Example:
%    createAATAMS_1profile_netcdf(CTD_DATA, METADATA)
%
% Other files required: none
% Other m-files required: getFieldDATA_sqlite,catstruct
% Subfunctions: none
% MAT-files required: none
%
% See also: aatams_sealtags_main,getFieldDATA_sqlite
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 10-Aug-2012

% [queryResult]=getSchemaInfo_psql(sqliteFile);
% tableNames=unique({queryResult.tableName}');
% fieldNames=unique({queryResult.fieldName}');

tablename = 'ctd';
isTableCTD = isTableSQLITE (tablename,sqliteFile);
 if isTableCTD
    [result1]   = getFieldDATA_sqlite(sqliteFile,tablename,'SAL_DBAR');
    [result2]   = getFieldDATA_sqlite(sqliteFile,tablename,'SAL_VALS');
    [result3]   = getFieldDATA_sqlite(sqliteFile,tablename,'N_SAL');
    
    
    [result4]   = getFieldDATA_sqlite(sqliteFile,tablename,'TEMP_DBAR');
    [result5]   = getFieldDATA_sqlite(sqliteFile,tablename,'TEMP_VALS');
    [result6]   = getFieldDATA_sqlite(sqliteFile,tablename,'N_TEMP');
    
    [result7]   = getFieldDATA_sqlite(sqliteFile,tablename,'COND_DBAR');
    [result8]   = getFieldDATA_sqlite(sqliteFile,tablename,'COND_VALS');
    [result9]   = getFieldDATA_sqlite(sqliteFile,tablename,'N_COND');
    
    [result10]  = getFieldDATA_sqlite(sqliteFile,tablename,'ref');
    [result100] = getFieldDATA_sqlite(sqliteFile,tablename,'PTT');
    
    
    [result11]  = getFieldDATA_sqlite(sqliteFile,tablename,'END_DATE');
    result11    = convertTimeSqlite(result11);
    
    
    [result12]  =getFieldDATA_sqlite(sqliteFile,tablename,'LAT');
    [result13]  =getFieldDATA_sqlite(sqliteFile,tablename,'LON');
    
    CTD_DATA    = catstruct(result1,result2,result3,result4,result5,result6,result7,result8,result9,result10,result100,result11,result12,result13);
else
    fprintf('%s - WARNING, table "ctd" is not present in Microsoft Access Database,Contact SMRU\n',datestr(now))
    CTD_DATA = struct;
end
clear result*

tablename         = 'deployments';
isTableDEPLOYMENT = isTableSQLITE (tablename,sqliteFile);
if isTableDEPLOYMENT
    
    [result1]  = getFieldDATA_sqlite(sqliteFile,'deployments','ref');
    
    isWMO      = isFieldSQLITE (tablename,'WMO',sqliteFile);
    if isWMO
        [result2]  = getFieldDATA_sqlite(sqliteFile,'deployments','WMO');
    else
        wmoCell    = cell(1,length(result1));%result1 is a reference
        result2    = cell2struct(wmoCell,'WMO',length(result1));
        fprintf('%s - WARNING, field "WMO" is not present in Microsoft Access Database. Database has a different format.Contact SMRU\n',datestr(now))
    end
    [result3]  = getFieldDATA_sqlite(sqliteFile,'deployments','COMMENTS');
    [result4]  = getFieldDATA_sqlite(sqliteFile,'deployments','SPECIES');
    [result5]  = getFieldDATA_sqlite(sqliteFile,'deployments','LOCATION');
    [result6]  = getFieldDATA_sqlite(sqliteFile,'deployments','PTT');
    [result7]  = getFieldDATA_sqlite(sqliteFile,'deployments','YEAR');
    [result8]  = getFieldDATA_sqlite(sqliteFile,'deployments','HOME_LAT');
    [result9]  = getFieldDATA_sqlite(sqliteFile,'deployments','HOME_LON');
    [result10] = getFieldDATA_sqlite(sqliteFile,'deployments','BODY');
    [result11] = getFieldDATA_sqlite(sqliteFile,'deployments','GREF');
    
    
    METADATA   = catstruct(result1,result2,result3,result4,result5,result6,result7,result8,result9,result10,result11);
else
    fprintf('%s - WARNING, table "deployments" is not present in Microsoft Access Database,contact smru\n',datestr(now))
    METADATA=struct;
end

end


function boolean = isFieldSQLITE (tablename,fieldname,sqliteFile)
    sqlQuery   = ['SELECT ' fieldname ' FROM ' tablename ';' ];
    commandStr = ['sqlite3 ' char(sqliteFile) ' ' '"' char(sqlQuery)  '"' ];
    [~,b]      = system(commandStr) ;

    if strfind(b,'Error: no such column')
        boolean = 0;
    else
        boolean = 1;
    end
end

function boolean = isTableSQLITE (tablename,sqliteFile)
    sqlQuery   = ['SELECT name FROM sqlite_master WHERE type=''table'' AND name=''' tablename ''';' ];
    commandStr = ['sqlite3 ' char(sqliteFile) ' ' '"' char(sqlQuery)  '"' ];
    [~,b]      = system(commandStr) ;

    if isempty(b)
        boolean = 0;
    else
        boolean = 1;
    end
end