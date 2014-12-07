function [queryResult]=getFieldDATA_sqlite(sqliteFile,table_name,fieldName)
%getFieldDATA_psql - load data and metadata from postgres database.
%PostGreSQL query of the table 'table_name' in the database 'dbName' on
%the server 'server', connecting with the port number 'port' and the
%username 'user'
%The function calls getPgPass.m which reads the file ~/.pgpass supposed to
%store the user password. The code is therefor free of password
% Requirements:
%    jdbc driver :'postgresql-9.1-902.jdbc4.jar' in the matlab path 
%    'startup.m' by adding:
%    javaaddpath([folder_location]/myJavaClasses/postgresql-9.1-902.jdbc4.jar');
%
% Syntax:  [queryResult]=getFieldDATA_psql(database_information,table_name,fieldName)
%
% Inputs:
%    database_information - structure of information about user,server,port
%    table_name - the name of the table to query
%    fieldName - the field or column name to query
%
% Outputs:
%    queryResult - results in the form of a structure
%
% Example: 
%    createAATAMS_1profile_netcdf(CTD_DATA, METADATA)
%
% Other files required: none
% Other m-files required: getFieldDATA_psql,catstruct,getPgPass
% Subfunctions: none
% MAT-files required: none
%
% See also: aatams_sealtags_main,loadCTD_datafromDB,getPgPass
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 09-Aug-2012

queryOutputFile = tempname;

%% count Nrows
sqlQuery = ['SELECT COUNT(*) FROM ' table_name];
commandStr = ['sqlite3 ' char(sqliteFile) ' ' '"' char(sqlQuery) '" > ' queryOutputFile ];
system(commandStr) ;
nRows = dlmread(queryOutputFile);
delete(queryOutputFile)

 
%% SQL query
if  strcmp('ctd',table_name)
    sqlQuery = strcat('select ',[{' '}],...,
        table_name,'."',fieldName, '"',[{' '}],...
        'from',[{' '}], table_name,[{' '}],...
        'ORDER BY END_DATE ;');
else
    sqlQuery = strcat('select ',[{' '}],...,
        table_name,'."',fieldName, '"',[{' '}],...
        'from',[{' '}], table_name,[{' '}],...
        ';');

end

queryOutputFile = tempname;
commandStr      = ['sqlite3 ' char(sqliteFile) ' ' '"' char(sqlQuery) '" > ' queryOutputFile ];
system(commandStr) ;

%replace empty lines with Nan
commandStr      = ['sed -i  ''s/^$/NaN/g'' '  queryOutputFile];
system(commandStr) ;


 emptyColum = 0;
 try

     data = readLineByLine (queryOutputFile);
     for ii = 1:nRows
            queryResult(ii).(fieldName) = data{ii};
     end
 catch
     try
         data = readStringColumnFromOutput(queryOutputFile);
         for ii = 1:nRows
             queryResult(ii).(fieldName) = data{1}{ii};
         end
     catch         
         emptyColum = 1;         
     end
 end

 if emptyColum
     for ii = 1:nRows
         queryResult(ii).(fieldName) = NaN;
     end
 end
 delete(queryOutputFile)

 end
 

function [data] = readStringColumnFromOutput(filename)
    fileID   = fopen(filename);
    data     = textscan(fileID,'%s');
    fclose(fileID);
end


%depreciated
%function line = readNlineFile(file,nLine)
%    commandStr = ['sed -n ''' num2str(nLine) '{p;q;}'' ' file];
%    [~, line] = system(commandStr) ;
%end

  
function data = readLineByLine (filename)
    fid = fopen(filename);    
    tline = fgets(fid);
    
    % check type of data (string of numerical) by reading first line
    isDataNum = 1;
    lineData = textscan(tline,'%f','delimiter',',');
     if isempty(lineData{1})
         isDataNum = 0;
     end
    
    i=1;
    if isDataNum
      while ischar(tline)
          lineData = textscan(tline,'%f','delimiter',',');
          
          lineData(cellfun('isempty',lineData)) = {NaN};
          data{i} = cell2mat(lineData);
          i =i+1;
          tline = fgets(fid);
      end
    elseif isDataNum == 0
       while ischar(tline)
  %       lineData = textscan(tline,'%s','delimiter',',');
        lineData = textscan(tline,'%*c');
        lineData(cellfun('isempty',lineData)) = {NaN};
        data{i} = char(lineData{1});
        i =i+1;
        tline = fgets(fid);
       end
    end
    fclose(fid);
end