function data = getColumnValues_sqlite (sqliteFile,tableName,columnName,varargin)
%varargin :
% 'orderBy','[YOUR SQL LITE STATEMENT HERE]'
%  example : getColumnValues_sqlite (sqliteFile,tableName,columnName,'orderBy','ORDER BY TIME')
% 
% 'timeFormat','time format of the sqlite column in a format readable by matlab'
%  example : getColumnValues_sqlite (sqliteFile,tableName,columnName, 'timeFormat','yyyy-mm-dd HH:MM:SS')

nVarargs = size(varargin,2); % option to convert the time faster by knowing the type format
if nVarargs > 1
    if    ( mod(nVarargs,2) == 0)
        for iiVarar = 1:2:nVarargs
            switch varargin{iiVarar};
                case 'orderBy'
                    optionalOrderQuery =  varargin{iiVarar + 1};
                case 'timeFormat'
                    timeFormat =  varargin{iiVarar + 1};
            end
        end
    else
        warning('Wrong number of optional inputs')
        optionalOrderQuery = '';
        timeFormat         = [];
    end
else
    optionalOrderQuery = '';
    timeFormat         = [];
end


queryOutputFile = tempname;
%% count Nrows
sqlQuery        = ['SELECT COUNT(*) FROM ' tableName];
commandStr      = ['sqlite3 ' char(sqliteFile) ' ' '"' char(sqlQuery) '" > ' queryOutputFile ];
system(commandStr) ;
nRows           = dlmread(queryOutputFile);
delete(queryOutputFile)


%% SQL query
sqlQuery = strcat('select ',[{' '}],...,
    tableName,'."',columnName, '"',[{' '}],...
    'from',[{' '}], tableName,[{' '}],...
    optionalOrderQuery ,' ;');

queryOutputFile = tempname;
commandStr      = ['sqlite3 ' char(sqliteFile) ' ' '"' char(sqlQuery) '" > ' queryOutputFile ];
system(commandStr) ;

%replace empty lines with Nan
commandStr      = ['sed -i  ''s/^$/NaN/g'' '  queryOutputFile];
system(commandStr) ;

% depending of the type of data, the data is stored in different matlab var types
columnType      = getColumnTypeSQLITE (sqliteFile,tableName,columnName);
switch columnType
    
    case 'DATETIME'
        if ~isempty(timeFormat)
            data = getDATETIME_sqlite (queryOutputFile,timeFormat);
        else
            data = getDATETIME_sqlite (queryOutputFile);
        end
    case 'DOUBLE'
        data = getDOUBLE_sqlite (queryOutputFile);
        
    case 'TEXT'
        data = getTEXT_sqlite (queryOutputFile);
        
    otherwise
        warning('Unexpected column type.');
end

delete(queryOutputFile)
end