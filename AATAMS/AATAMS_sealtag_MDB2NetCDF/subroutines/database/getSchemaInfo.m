function [queryResult]=getSchemaInfo_psql(server,port,user,dbName,schema_name)

global AGGREGATED_DATA_FOLDER;
global SCRIPT_FOLDER;
global TEMPORARY_FOLDER;

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
