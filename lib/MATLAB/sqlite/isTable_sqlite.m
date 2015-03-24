function boolean = isTable_sqlite (tableName,sqliteFile)
%% isTbale_sqlite  checks the existence of a table in a sqlite file
%
%
% Inputs: tableName   : string of a table
%         sqliteFile  : path to a sqlite file
%   
%
% Outputs: boolean    : 0 if table does not exist
%                       1 if exist
%
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Dec 2014; Last revision: 09-Dec-2014

sqlQuery   = ['SELECT name FROM sqlite_master WHERE type=''table'' AND name=''' tableName ''';' ];
commandStr = ['sqlite3 ' char(sqliteFile) ' ' '"' char(sqlQuery)  '"' ];
[~,b]      = system(commandStr) ;

if isempty(b)
    boolean = 0;
else
    boolean = 1;
end
end
