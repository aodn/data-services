function columnType = getColumnType_sqlite (sqliteFile, tableName, columnName)
%% getColumnType_sqlite finds datatype of SQLITE column by reading the PRAGMA table
% 
% Inputs: sqliteFile   : path to sqlite
%         tableName    : string of table name to check
%         columnName   : string of column name to check type
%
% Outputs: columnType      : string of column type. SQLITE value
%
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Dec 2014; Last revision: 09-Dec-2014


sqlQuery         = ['PRAGMA table_info(''' tableName ''')'];
queryOutputFile  = tempname;

commandStr       = ['sqlite3 ' char(sqliteFile) ' ' '"' char(sqlQuery) '" > ' queryOutputFile ];
system(commandStr) ;
fileId           = fopen(queryOutputFile);
pragmaOutput     = textscan(fileId,'%d %s %s %d %d %d','delimiter', '|');
fclose(fileId);
delete(queryOutputFile)

% find the type of columnName
columnNames      = pragmaOutput{2};
columnTypes      = pragmaOutput{3};

indexColumnNname = find(ismember(columnNames,columnName) );
columnType       = columnTypes{indexColumnNname};

end
