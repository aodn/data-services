function print_message(filename,msg,varargin)

fid_w = fopen(filename,'a');
if size(varargin,2) > 0 
    fprintf(fid_w,'%s %s %s \r\n',datestr(clock),msg,varargin{1});
else
    fprintf(fid_w,'%s %s \r\n',datestr(clock),msg);
end
fclose(fid_w);