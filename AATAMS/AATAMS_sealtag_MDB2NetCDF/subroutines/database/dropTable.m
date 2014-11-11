function dropTable(database_information)
%dropTable - drop all tables belonging to database_information.dbName, public schema
%
% Syntax:  dropTable(database_information)
%
% Inputs:
%    database_information - structure of database options
%
% Outputs:
%
%
% Example:
%    dropTable(database_information)
%
% Subfunctions: none
% Other m-files required: none
% MAT-files required: none
% Other files required: none
%
% See also: aatams_sealtags_main,getSchemaInfo_psql
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 13-Aug-2012
global DATA_FOLDER;

[queryResult]=getSchemaInfo_psql(database_information);
if ~isempty(fieldnames(queryResult))
    tableNames=unique({queryResult.tableName}');
    
    
    filetext=fullfile(DATA_FOLDER,filesep,'dropTable.sql');
    fid = fopen(filetext, 'w');
    for iiTable=1:length(tableNames)
        fprintf(fid,'DROP TABLE IF EXISTS "%s";\n',tableNames{iiTable});
    end
    fclose(fid);
    
    %% execute command
    commandStr=['psql -q -h localhost -U postgres -w -d ', database_information.dbName, ' -f ',filetext,...
        ';rm -f ',filetext,';'];
    system(commandStr) ; % '-q' option avoids all the echo
end