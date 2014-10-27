function print_message(filename,msg,varargin);
% PRINT MESSAGE TO A LOG FILE
% INPUT : 
%		  -filename 	: name of output file
%		  - msg 		: message to be written
% 		  -varargin 	: optional comment to be added to the message 
%Author: B.Pasquer July 2013
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fid_w = fopen(filename,'a');
if size(varargin,2) > 0 
    fprintf(fid_w,'%s %s %s \r\n',datestr(clock),msg,varargin{1})
else
    fprintf(fid_w,'%s %s \r\n',datestr(clock),msg);
end
fclose(fid_w);