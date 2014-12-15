function boolean = isFieldSQLITE (tablename,fieldname,sqliteFile)
% looks for the existence of a column in an sqlite table
sqlQuery   = ['SELECT ' fieldname ' FROM ' tablename ';' ];
commandStr = ['sqlite3 ' char(sqliteFile) ' ' '"' char(sqlQuery)  '"' ];
[~,b]      = system(commandStr) ;

if strfind(b,'Error: no such column')
    boolean = 0;
else
    boolean = 1;
end
end
