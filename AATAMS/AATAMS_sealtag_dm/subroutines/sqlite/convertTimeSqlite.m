function outputStructure = convertTimeSqlite(sourceStructure)

fieldname        = fieldnames(sourceStructure);
timezone_datenum = getMachineTimezone;

for ii = 1:length(sourceStructure)
    outputStructure(ii).(fieldname{1}) = datenum(1970, 1,1, 0,0, sourceStructure(ii).(fieldname{1})/1000 ) + timezone_datenum;
end
end

 function timezone_datenum = getMachineTimezone
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
  