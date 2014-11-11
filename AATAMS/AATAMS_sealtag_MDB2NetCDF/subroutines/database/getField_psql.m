function [queryResult]=getFieldDATA_psql(database_information,table_name,fieldName)
% PostGreSQL query of the table 'table_name' in the database 'dbName' on
% the server 'server', connecting with the port number 'port' and the
% username 'user'
% The function calls getPgPass.m which reads the file ~/.pgpass supposed to
% store the user password. The code is therefor free of password
% The function queries only 4 columns, the vessel name (or callsign), the
% opendap url, and the time coverage.
% the function requires to have the jdbc driver
% 'postgresql-9.1-902.jdbc4.jar' in the matlab path 'startup.m' by adding
% this line:
% javaaddpath([folder_location]/myJavaClasses/postgresql-9.1-902.jdbc4.jar');

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
sql=strcat('select ',[{' '}],...,
    table_name,'."',fieldName, '"',[{' '}],...
    'from',[{' '}], schema_name,'.',table_name,[{' '}],...
    ';');

ps=conn.prepareStatement(sql);
rs=ps.executeQuery();

%% Read the results into an array of result structs
count=0;
queryResult=struct;
while rs.next()
    count=count+1;
    queryResult(count).(fieldName)=char(rs.getString(1));
end
end

