function data = getTEXT_sqlite (fileName)
%% getTEXT_sqlite reads the text output of a select * from a
% sqlite file and returns a cell array of string
% This is for a column of TEXT type
%
% THIS FUNCTION IS CALLED BY getColumnValues_sqlite.m
%
% Inputs: fileName   : text output of a select query
%
% Outputs: data      : cell array of data
%
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Dec 2014; Last revision: 09-Dec-2014

fid   = fopen(fileName);
tline = fgets(fid);

i     = 1;
while ischar(tline)
    data{i} = tline;
    i       = i+1;
    tline   = fgets(fid);
end

fclose(fid);

end

