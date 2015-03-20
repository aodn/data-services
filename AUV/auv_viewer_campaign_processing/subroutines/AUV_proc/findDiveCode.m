function [dive_code_name,diveNumber] = findDiveCode (Dive)

dive_name_seperate =textscan(Dive,'r%d %d %s %s %s %s %s %s','delimiter', '_');

%% Find where the dive number is written on the diving name
for t=3:length(dive_name_seperate)
    if  isfinite(str2double(dive_name_seperate{t}))
        diveNumber = t;
        diveNumber = str2double(dive_name_seperate{diveNumber});
    end
end

%% second way in case the dive number is for example '18a' and not '18'
if ~exist('diveNumber','var')
    for t=3:length(dive_name_seperate)
        a=regexp(dive_name_seperate{t},'\d+','match');
        if ~isempty(a)
            if  isfinite(str2double(a{1}))
                diveNumber=str2double(a{1});
                break
            end
        end
    end
end

%% third way, we makle the dive number up
if ~exist('diveNumber','var')
    diveNumber=0;
end

%% create a dive code name readable by the user
dive_code_name=' ';
for t=3:length(dive_name_seperate)
    if t==3
        dive_code_name=strcat(char(dive_name_seperate{t}));
    elseif t ~= diveNumber && ~isempty(dive_name_seperate{t})
        dive_code_name=strcat(dive_code_name,{' '},char(dive_name_seperate{t}));
    end
    
dive_code_name = char(dive_code_name);
end