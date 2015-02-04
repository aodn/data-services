function data = getDOUBLE_sqlite (filename)

fid = fopen(filename);
tline = fgets(fid);

i=1;
while ischar(tline)
    lineData = textscan(tline,'%f','delimiter',',');
    
    lineData(cellfun('isempty',lineData)) = {NaN};
    data{i} = cell2mat(lineData);
    i =i+1;
    tline = fgets(fid);
end
data = cell2mat(data);
fclose(fid);

end

