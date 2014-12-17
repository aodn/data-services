function [queryResult]=readDB(server,dbName,port,user,password,table_name)
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

% [password]=getPgPass(server,port,user);
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
    table_name,'.callsign, ',...,
    table_name,'.download_url, ',...,
    table_name,'.time_coverage_start,',...,
    table_name,'.time_coverage_end',[{' '}],...
    'from soop.',table_name,[{' '}],...
    'ORDER BY',[{' '}],table_name,'."time_coverage_start";');

ps=conn.prepareStatement(sql);
rs=ps.executeQuery();

%% Read the results into an array of result structs
count=0;
queryResult=struct;
while rs.next()
    count=count+1;
    queryResult(count).vesselName=char(rs.getString(1));
    queryResult(count).opendap=char(rs.getString(2));
    queryResult(count).timeStart=char(rs.getString(3));
    queryResult(count).timeEnd=char(rs.getString(4));
end
end

