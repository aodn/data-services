function [status] = slocum_realtime_subfunction1_UNIX_v3(filename,deployment,nbnetcdf)
%
outputdir = readConfig('output_dir');
processingdir = readConfig('processing_dir');
archivedir = readConfig('archive_dir');
positiontxtfile = readConfig('position_txt_file');
SQLupdatefile = readConfig('SQL_update_file');
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%OUTPUT FILES
%
%OUTPUT FILE WHICH CONTAINED THE POSITION ALREADY PROCESSED
fileoutput1 = fullfile(outputdir,processingdir,strcat(deployment,positiontxtfile));
%OUTPUT FILE CONTAINING THE SQL COMMAND TO INPUT THE DATA IN THE DATABASE
fileoutput2 = fullfile(outputdir,processingdir,strcat(deployment,SQLupdatefile));
%
%SAVE THE FILE IN AN ARCHIVE DIRECTORY
fileoutput3 = fullfile(outputdir,archivedir,deployment,strcat(deployment,'_SQL_update_',datestr(clock,'ddmmyyyyTHHMMSSZ'),'.txt'));
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%METADATA
%
glidertype = readConfig('glider_type');
%
is_SOTS = str2num(readConfig('isSOTS'));
if is_SOTS == 1
    SOTSabstract = readConfig('SOTS_abstract');
    SOTSmetadata = readConfig('SOTS_metadata');
end
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fid = fopen(filename,'r');
line = fgetl(fid);
data{1} = line;
%CREATION OF THE VARIABLE I
i=2;
%
%READ ALL THE DATA
while line~=-1,
  line=fgetl(fid);
  data{i} = line ;
  i=i+1;
end
%
dimfile = length(data)-1;
%
j=1;
for i=10:dimfile
    indexspace = find (isspace(data{i})==1);
    temptime = datevec(datenum('01-01-1970 00:00:00','dd-mm-yyyy HH:MM:SS')+(str2num(data{i}(1:indexspace(1)-1)))/60/60/24);
    datetime(1,j) = temptime(1);
    datetime(2,j) = temptime(2);
    datetime(3,j) = temptime(3);
    datetime(4,j) = temptime(4);
    datetime(5,j) = temptime(5);
    datetime(6,j) = temptime(6);
    latitude(j) = str2num(data{i}(indexspace(1)+1:indexspace(2)-1));
    longitude(j) = str2num(data{i}(indexspace(2)+1:end));
%
    j=j+1;
end
dimfile =length(latitude);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%CHECK IF A FILE CONTAINING THE POSITIONS OF THE SEAGLIDER HAS ALREADY BEEN
%CREATED
fileinfolder = fullfile(outputdir,processingdir,strcat(deployment,'_position*.txt'));
%
testpos = 0;
try
testpos = length(dir(fileinfolder));
end
%
value_pkid=strcat('(Select pkid from anfog.anfog_realtime_deployment where name ='' ',deployment,''') ' );
if (testpos == 0)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%FIRST TIME THE FILE WILL BE CREATED
    if (~exist(fullfile(outputdir,processingdir),'dir'));
       mkdir(fullfile(outputdir,processingdir));
    end
    fid_w = fopen(fileoutput1,'w');
    for i=1:dimfile    
     fprintf(fid_w,'%s %s %s\n',num2str(datestr(datenum(datetime(1,i),datetime(2,i),datetime(3,i),datetime(4,i),datetime(5,i),datetime(6,i)))),num2str(latitude(i)),num2str(longitude(i)));
    end
    fclose(fid_w);
    fid_w2 = fopen(fileoutput2,'w');
    if is_SOTS == 1
            if (nbnetcdf == 0)
        fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_deployment(name,glider_type,abstract,metadata)\n');
        fprintf(fid_w2,'VALUES (\''%s\'', \''%s\'', \''%s\'', \''%s\'');\n',deployment,glidertype,SOTSabstract,SOTSmetadata);   
            else
        fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_deployment(name,glider_type,abstract,metadata,summary_plot)\n');
        fprintf(fid_w2,'VALUES (\''%s\'', \''%s\'', \''%s\'', \''%s\'',TRUE);\n',deployment,glidertype,SOTSabstract,SOTSmetadata);                  
            end
    else
            if (nbnetcdf == 0)
        fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_deployment(name,glider_type)\n');
        fprintf(fid_w2,'VALUES (\''%s\'',\''%s\'');\n',deployment,glidertype);    
            else
        fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_deployment(name,glider_type,summary_plot)\n');
        fprintf(fid_w2,'VALUES (\''%s\'',\''%s\'',TRUE);\n',deployment,glidertype);                 
            end
    end
    for i=2:dimfile
        if is_SOTS == 1
    fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_track(fk_anfog_realtime_deployment,time_start,latitude,longitude, geom)\n');
    fprintf(fid_w2,'VALUES (%s, \''%s\'', %s, %s,LineFromText(\''LINESTRING(',value_pkid,num2str(datestr(datenum(datetime(1,i),datetime(2,i),datetime(3,i),datetime(4,i),datetime(5,i),datetime(6,i)),'yyyy-mm-ddTHH:MM:SSZ')),num2str(latitude(i)),num2str(longitude(i)));
    fprintf(fid_w2, '%s %s , %s %s)\'',4326));\n',num2str(longitude(i-1)),num2str(latitude(i-1)),num2str(longitude(i)),num2str(latitude(i)));       
        else
    fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_track(fk_anfog_realtime_deployment,time_start,latitude,longitude, geom)\n');
    fprintf(fid_w2,'VALUES (%s, \''%s\'', %s, %s,LineFromText(\''LINESTRING(',value_pkid,num2str(datestr(datenum(datetime(1,i),datetime(2,i),datetime(3,i),datetime(4,i),datetime(5,i),datetime(6,i)),'yyyy-mm-ddTHH:MM:SSZ')),num2str(latitude(i)),num2str(longitude(i)));
    fprintf(fid_w2, '%s %s , %s %s)\'',4326));\n',num2str(longitude(i-1)),num2str(latitude(i-1)),num2str(longitude(i)),num2str(latitude(i)));
        end
    end
    fclose(fid_w2);   
%
status = 1;
%
    if (~exist(fullfile(outputdir,archivedir,deployment),'dir'));
       mkdir(fullfile(outputdir,archivedir,deployment));
    end
    copyfile(fileoutput2,fileoutput3);
%
else
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%THE FILE HAS ALREADY BEEN CREATED
%THE FOLLOWING LINES ARE CHECKING THE DATA ALREADY PROCESSED    
    fid = fopen(fileoutput1);
    C = textscan(fid,'%s %s %f %f');
    fclose(fid);
%
 status = 2;   
%
    if (length(C{1})<dimfile)
%
        z=0;
        for i=length(C{1})+1:dimfile
            z=z+1;
        end
%CREATION OF AN UPDATED VERSION OF THE FILE CONTAINING THE PROCESSED POSITION         
        fid_w = fopen(fileoutput1,'w');
        for i=1:dimfile
        fprintf(fid_w,'%s %s %s\n',num2str(datestr(datenum(datetime(1,i),datetime(2,i),datetime(3,i),datetime(4,i),datetime(5,i),datetime(6,i)))),num2str(latitude(i)),num2str(longitude(i)));
        end
        fclose(fid_w);
%WRITE THE SQL COMMAND IN THE OUTPUT FILE
    fid_w2 = fopen(fileoutput2,'w');
    for i=length(C{1})+1:dimfile
        if is_SOTS == 1
    fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_track(fk_anfog_realtime_deployment,time_start,latitude,longitude, geom)\n');
    fprintf(fid_w2,'VALUES (%s, \''%s\'', %s, %s,LineFromText(\''LINESTRING(',value_pkid,num2str(datestr(datenum(datetime(1,i),datetime(2,i),datetime(3,i),datetime(4,i),datetime(5,i),datetime(6,i)),'yyyy-mm-ddTHH:MM:SSZ')),num2str(latitude(i)),num2str(longitude(i)));
    fprintf(fid_w2, '%s %s , %s %s)\'',4326));\n',num2str(longitude(i-1)),num2str(latitude(i-1)),num2str(longitude(i)),num2str(latitude(i)));
        else
    fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_track(fk_anfog_realtime_deployment,time_start,latitude,longitude, geom)\n');
    fprintf(fid_w2,'VALUES (%s, \''%s\'', %s, %s,LineFromText(\''LINESTRING(',value_pkid,num2str(datestr(datenum(datetime(1,i),datetime(2,i),datetime(3,i),datetime(4,i),datetime(5,i),datetime(6,i)),'yyyy-mm-ddTHH:MM:SSZ')),num2str(latitude(i)),num2str(longitude(i)));
    fprintf(fid_w2, '%s %s , %s %s)\'',4326));\n',num2str(longitude(i-1)),num2str(latitude(i-1)),num2str(longitude(i)),num2str(latitude(i)));
        end
    end
    fclose(fid_w2); 
    if (~exist(fullfile(outputdir,archivedir,deployment),'dir'))
       mkdir(fullfile(outputdir,archivedir,deployment));
    end
    copyfile(fileoutput2,fileoutput3);
    else
        status = 3;
        fid_w2 = fopen(fileoutput2,'w');
        fclose(fid_w2);
    end
end