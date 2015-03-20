function  value=getUUID(prop,fileLocation,delim)
%getUUID Returns the uuid value of the specified diveCampaign. This value
%is used for the metadata record
%
% Inputs:
%
%   prop  - Name of the [campaign/dive]. If the name does not map to a property 
%           listed in the config file, an error is raised.
%
%   file  - Name of the config file. 
%
%   delim -  Delimiter character/string. Defaults to '='.
%
% Outputs:
%   value - Value of the property. 
fid = fopen(fileLocation, 'rt');
if fid == -1, error(['could not open ' file]); end

lines = textscan(fid, '%s%s', 'Delimiter', delim, 'CommentStyle', '#');

fclose(fid);

if isempty(lines), error([file ' is empty']); end

names = lines{1};
vals  = lines{2};

if strcmp(prop, '*')
    value = lines;
    return;
end

% find the requested property
for k = 1:length(names)
    
    name = strtrim(names{k});
    
    if ~strcmp(name, prop), continue; end
    
    value = strtrim(vals{k});
    return;
    
end
error([prop ' is not a property']);
end