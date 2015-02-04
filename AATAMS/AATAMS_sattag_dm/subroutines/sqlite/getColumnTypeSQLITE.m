function columnType = getColumnTypeSQLITE (sqliteFile, tableName, columnName)
%% find datatype of SQLITE column by reading the PRAGMA table
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
