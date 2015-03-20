 function timezone_datenum = getMachineTimezone
% find the timnezone of the linux machine
 commandStr = ['date +%:z'];
 [~, timezone] = system(commandStr) ;
 [HH_MM] = textscan(timezone,'%f:%f');
 if strcmp(timezone(1),'+')
     timezone_datenum = datenum(0,0,0,HH_MM{1},HH_MM{2},0);
 elseif  strcmp(timezone(1),'-')
     timezone_datenum = datenum(0,0,0,HH_MM{1},HH_MM{2},0);
 else
     timezone_datenum = datenum(0,0,0,HH_MM{1},HH_MM{2},0);
 end
 end