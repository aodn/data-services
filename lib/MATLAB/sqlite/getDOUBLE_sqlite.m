function data = getDOUBLE_sqlite (filename)
%% getDOUBLE_sqlite reads the text output of a select * from a
% sqlite file and returns a mat array
% This is for a column of DOUBLE/NUMERIC type
%
% THIS FUNCTION IS CALLED BY getColumnValues_sqlite.m
%
% Inputs: fileName   : text output of a select query
%
% Outputs: data      :  mat array of data
%
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Dec 2014; Last revision: 09-Dec-2014

fid   = fopen(filename);
tline = fgets(fid);

i     = 1;
while ischar(tline)
    lineData                              = textscan(tline,'%f','delimiter',',');
    
    lineData(cellfun('isempty',lineData)) = {NaN};
    data{i}                               = cell2mat(lineData);
    i                                     =i+1;
    tline                                 = fgets(fid);
end

data = cell2mat(data);
fclose(fid);

end

