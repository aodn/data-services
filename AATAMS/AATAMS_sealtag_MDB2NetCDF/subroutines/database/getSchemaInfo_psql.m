function [queryResult]=getSchemaInfo_psql(database_information)
%getSchemaInfo_psql - find the uuid code according to a ref code.
%
% Syntax:  [queryResult]=getSchemaInfo_psql(database_information)
%
% Inputs:
%    database_information - structure of database options
%
% Outputs:
%    queryResult - structure
%
% Example:
%    [queryResult]=getSchemaInfo_psql(database_information)
%
% Subfunctions: none
% Other m-files required: none
% MAT-files required: none
% Other files required: none
%
% See also: aatams_sealtags_main
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 13-Aug-2012
server=database_information.server;
dbName=database_information.dbName;
port=database_information.port;
user=database_information.user;
schema_name=database_information.schema_name;


[password]=getPgPass(server,port,user);
%% server setup
props=java.util.Properties;
props.setProperty('user', user);
props.setProperty('password', password);
props.setProperty('ssl','true');
props.setProperty('sslfactory','org.postgresql.ssl.NonValidatingFactory');

%% Create the database connection (port 5432 is the default postgres choose on installation)
driver=org.postgresql.Driver;
url = strcat('jdbc:postgresql://',server,':',num2str(port),'/',dbName);
conn=driver.connect(url, props);


%% SQL query
sql=(strcat('select ',[{' '}],...
    'tables.table_name, ',[{' '}],...
    'columns.column_name',[{' '}],...
    'from information_schema.tables',[{' '}],...
    'inner join information_schema.columns ',[{' '}],...
    'on information_schema.columns.table_name = information_schema.tables.table_name',[{' '}],...
    'where tables.table_schema = ''',schema_name,'''',[{' '}],...
    'and tables.table_type = ''BASE TABLE''',[{' '}],...
    'order by tables.table_name, columns.column_name;'));
%  sql=strcat('select ',[{' '}],...,
%     table_name,'."',fieldName, '"',[{' '}],...
%     'from',[{' '}], schema_name,'.',table_name,[{' '}],...
%     ';');

ps=conn.prepareStatement(sql);
rs=ps.executeQuery();

%% Read the results into an array of result structs
count=0;
queryResult=struct;

while rs.next()
    count=count+1;
    queryResult(count).tableName=char(rs.getString(1));
    queryResult(count).fieldName=char(rs.getString(2));
end
    
end
