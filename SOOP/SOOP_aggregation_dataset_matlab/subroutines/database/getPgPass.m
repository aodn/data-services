function [password]=getPgPass(server,port,user)
% Read the required password to connect to the server If the line exist in 
% the file ~/.pgpass, otherwise return an empty one.

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