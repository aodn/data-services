function modifyNetCDF_Structure(filename,filepath)
%modifyNetCDFStructyre
% this function creates a ncml file of the filename in order to rename the
% variables in the netcdf file
% Author: Laurent Besnard <laurent.besnard@utas,edu,au>
% Nov 2010; Last revision: 26-Nov-2012

ncmlFile     = [filepath  filename(1:end-3) '.ncml'];
outputNETCDF = [filepath  filename(1:end-3) '.nc2'];
ncmlFile_fid = fopen(ncmlFile, 'w+');


fprintf(ncmlFile_fid,'<netcdf xmlns="http://www.unidata.ucar.edu/namespaces/netcdf/ncml-2.2" location="%s">\n',[filepath  filename]);

%% modify variable names
fprintf(ncmlFile_fid,'  <variable name="TIME" orgName="time" type="double" />\n');
fprintf(ncmlFile_fid,'</netcdf> \n');
fclose(ncmlFile_fid);

%% write NetCDF from NCML, java code
write_NC_Command=sprintf('java -classpath ".:lib/java/class/toolsUI-4.2.jar" AggregateNcML %s %s',ncmlFile,outputNETCDF);

[status,result] = unix(write_NC_Command);

if status == 1 % 0 is success , 1 is not , pretty weird matlab standard
    fprintf('%s - Warning, ncml transformation could not be performed for file %s\n',datestr(now),filename)
    delete(ncmlFile)

elseif   status==0
    delete(ncmlFile)
    delete([filepath  filename])
    movefile(outputNETCDF,outputNETCDF(1:end-1))
end