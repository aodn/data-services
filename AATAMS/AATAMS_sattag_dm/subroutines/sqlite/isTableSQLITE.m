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