function boolean = isField_sqlite (tableName,fieldName,sqliteFile)
%% isField_sqlite looks for the existence of a column in an sqlite table
%
%
% Inputs: tableName   : string of a table
%         fieldName   : string of a field/column 
%         sqliteFile  : path to a sqlite file
%   
%
% Outputs: boolean    : 0 if column/field does not exist
%                       1 if exist
%
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Dec 2014; Last revision: 09-Dec-2014

sqlQuery   = ['SELECT ' fieldName ' FROM ' tableName ';' ];
commandStr = ['sqlite3 ' char(sqliteFile) ' ' '"' char(sqlQuery)  '"' ];
[~,b]      = system(commandStr) ;

if strfind(b,'Error: no such column')
    boolean = 0;
else
    boolean = 1;
end
end
