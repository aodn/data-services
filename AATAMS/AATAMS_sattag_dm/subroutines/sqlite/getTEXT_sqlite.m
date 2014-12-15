function data = getTEXT_sqlite (filename)

fid = fopen(filename);
tline = fgets(fid);
i=1;
while ischar(tline)
    data{i} = tline;
    i =i+1;
    tline = fgets(fid);
end
fclose(fid);

end

