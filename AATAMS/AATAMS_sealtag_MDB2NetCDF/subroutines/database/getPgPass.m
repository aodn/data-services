function [password]=getPgPass(server,port,user)
%getPgPass - find the user password for one server and port.
%Read the required password to connect to the server If the line exist in
%the file ~/.pgpass, otherwise return an empty one.
%
% Syntax:  [password]=getPgPass(server,port,user)
%
% Inputs:
%    server - structure of information about user,server,port
%    port - the name of the table to query
%    user - the field or column name to query
%
% Outputs:
%    queryResult - results in the form of a structure
%
% Example:
%   [password]=getPgPass('localhost',5432,'postgres')
%
% Other files required: ~/.pgpass
% Other m-files required: getFieldDATA_psql,catstruct,getPgPass
% Subfunctions: none
% MAT-files required: none
%
% See also:
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 09-Aug-2012


filename='~/.pgpass';
if exist('~/.pgpass','file')==2
    
    fileID = fopen(filename,'r');
    tline = fgetl(fileID);
    A=regexp(tline,strcat(server,':',num2str(port),':.*?:',user,':.*?') ,'end');
    while ischar(tline) && isempty(A)
        tline = fgetl(fileID);
        A=regexp(tline,strcat(server,':',num2str(port),':.*?:',user,':.*?') ,'end');
    end
    password=tline(A+1:end);
    fclose(fileID);
else
    password=[];
end
end