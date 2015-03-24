function [CTD_DATA, METADATA] = loadCTD_datafromDB(sqliteFile)
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
% Other m-files required: getColumnValues_sqlite,catstruct
% Subfunctions: none
% MAT-files required: none
%
% See also: aatams_sealtags_main,getColumnValues_sqlite
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 10-Aug-2012

% [queryResult]=getSchemaInfo_psql(sqliteFile);
% tableNames=unique({queryResult.tableName}');
% fieldNames=unique({queryResult.fieldName}');

tablename  = 'ctd';
isTableCTD = isTable_sqlite(tablename,sqliteFile);
if isTableCTD

    columnNames = {'SAL_DBAR','SAL_VALS','N_SAL','TEMP_DBAR','TEMP_VALS','N_TEMP','COND_DBAR','COND_VALS','N_COND','ref','PTT','LAT','LON'};
    for iiCol = 1 : length (columnNames)
        CTD_DATA.(columnNames{iiCol}) = getColumnValues_sqlite (sqliteFile,tablename,columnNames{iiCol}, 'orderBy','ORDER BY END_DATE');
    end

    % load time data
    columnName            = 'END_DATE';
    CTD_DATA.(columnName) = getColumnValues_sqlite (sqliteFile,tablename,columnName, 'orderBy','ORDER BY END_DATE','timeFormat','yyyy-mm-dd HH:MM:SS');

else
    fprintf('%s - WARNING, table "ctd" is not present in Microsoft Access Database,Contact SMRU\n',datestr(now))
    CTD_DATA = struct;
end

tablename         = 'deployments';
isTableDEPLOYMENT = isTable_sqlite (tablename,sqliteFile);
if isTableDEPLOYMENT

    columnNames = {'COMMENTS','SPECIES','LOCATION','PTT','YEAR','HOME_LAT','HOME_LON','BODY','GREF','ref'};
    for iiCol = 1 : length (columnNames)
        METADATA.(columnNames{iiCol}) = getColumnValues_sqlite (sqliteFile,tablename,columnNames{iiCol});
    end

    isWMO      = isField_sqlite (tablename,'WMO',sqliteFile);
    if isWMO
        METADATA.('WMO') = getColumnValues_sqlite (sqliteFile,tablename,'WMO');
    else
        wmoCell    = cell(1,length(METADATA.ref));%result1 is a reference
        METADATA.('WMO')    = cell2struct(wmoCell,'WMO',length(result1));
        fprintf('%s - WARNING, field "WMO" is not present in Microsoft Access Database. Database has a different format.Contact SMRU\n',datestr(now))
    end


else
    fprintf('%s - WARNING, table "deployments" is not present in Microsoft Access Database,contact smru\n',datestr(now))
    METADATA=struct;
end

end