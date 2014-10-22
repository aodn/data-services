function [status] = seaglider_realtime_subfunction1_UNIX_vB(filename,deployment,nbnetcdf)
%
currentdir = readConfig('current_dir');
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
%USE OF THE GREP SUBROUTINE TO FIND THE OCCURENCE OF THE CHARACTER 'GPS' IN
%THE FILE
[Fl,P] = grep('-n',{'GPS'},{filename});
%dimension
dimfile = length(P.match);
%
%READ THE VALUES AVAILABLE IN THE COMMUNICATION LOG FILE
%WE WILL USE ONLY 6 VARIABLES
%var1 : numbe rof dive
%var2 : number of calls
%var3 : number of missed communication
%var4 : date and time
%var5 : latitude
%var6 : longitude
%
%METADATA SPECIFIC TO SOME DEPLOYMENT
glidertype = readConfig('glider_type');
is_SOTS = readConfig('isSOTS');
if is_SOTS == 1
    SOTSabstract = readConfig('SOTS_abstract');
    SOTSmetadata = readConfig('SOTS_metadata');
end
%
%READ THE FIRST VALUE
temp = P.match{1};
parts = textscan(temp, '%s %s %s %s %s %s %s %s %s', 'Delimiter', ',');
%
latitudeparts = textscan(parts{4}{1:end},'%s %s', 'Delimiter', '.');
%
if (str2double(latitudeparts{2}{1}) > 0)
    decimalpart = str2double(latitudeparts{2}{1})/1000;
elseif (str2double(latitudeparts{2}{1}) > 10)
    decimalpart = str2double(latitudeparts{2}{1})/100;
elseif (str2double(latitudeparts{2}{1}) > 100)
    decimalpart = str2double(latitudeparts{2}{1})/10;
end
%
if (str2double(latitudeparts{1}{1}(1:end-2)) > 0)
    testpart1 = str2double(latitudeparts{1}{1}(1:end-2));
    testpart2 = ((str2double(latitudeparts{1}{1}(end-1:end))+decimalpart)/60);
    templat = round(10000*(testpart1+testpart2))/10000;
else
    testpart1 = str2double(latitudeparts{1}{1}(1:end-2));
    testpart2 = ((str2double(latitudeparts{1}{1}(end-1:end))+decimalpart)/60);
    templat = round(10000*(testpart1-testpart2))/10000;
end
%
longitudeparts = textscan(parts{5}{1:end},'%s %s', 'Delimiter', '.');
%
if (str2double(longitudeparts{2}{1}) > 0)
    decimalpart = str2double(longitudeparts{2}{1})/1000;
elseif (str2double(longitudeparts{2}{1}) > 10)
    decimalpart = str2double(longitudeparts{2}{1})/100;
elseif (str2double(longitudeparts{2}{1}) > 100)
    decimalpart = str2double(longitudeparts{2}{1})/10;
end
%
if (str2double(longitudeparts{1}{1}(1:end-2)) > 0)
    testpart3 = str2double(longitudeparts{1}{1}(1:end-2));
    testpart4 = ((str2double(longitudeparts{1}{1}(end-1:end))+decimalpart)/60);
    templon = round(10000*(testpart3+testpart4))/10000;
else
    testpart3 = str2double(longitudeparts{1}{1}(1:end-2));
    testpart4 = ((str2double(longitudeparts{1}{1}(end-1:end))+decimalpart)/60);
    templon = round(10000*(testpart3-testpart4))/10000;
end
%
j=1;
for i=2:dimfile
%READ EACH LINE OF THE FILE
%CREATION OF A TEMPORARY VARIABLE
    temp = P.match{i};
%
    parts = textscan(temp, '%s %s %s %s %s %s %s %s %s', 'Delimiter', ',');
%
    latitudeparts = textscan(parts{4}{1:end},'%s %s', 'Delimiter', '.');
%
    if (str2double(latitudeparts{2}{1}) > 0)
        decimalpart = str2double(latitudeparts{2}{1})/1000;
    elseif (str2double(latitudeparts{2}{1}) > 10)
        decimalpart = str2double(latitudeparts{2}{1})/100;
    elseif (str2double(latitudeparts{2}{1}) > 100)
        decimalpart = str2double(latitudeparts{2}{1})/10;
    end
%
    if (str2double(latitudeparts{1}{1}(1:end-2)) > 0)
        testpart1 = str2double(latitudeparts{1}{1}(1:end-2));
        testpart2 = ((str2double(latitudeparts{1}{1}(end-1:end))+decimalpart)/60);
        templat1 = round(10000*(testpart1+testpart2))/10000;
    else
        testpart1 = str2double(latitudeparts{1}{1}(1:end-2));
        testpart2 = ((str2double(latitudeparts{1}{1}(end-1:end))+decimalpart)/60);
        templat1 = round(10000*(testpart1-testpart2))/10000;
    end
%
    longitudeparts = textscan(parts{5}{1:end},'%s %s', 'Delimiter', '.');
%
    if (str2double(longitudeparts{2}{1}) > 0)
        decimalpart = str2double(longitudeparts{2}{1})/1000;
    elseif (str2double(longitudeparts{2}{1}) > 10)
        decimalpart = str2double(longitudeparts{2}{1})/100;
    elseif (str2double(longitudeparts{2}{1}) > 100)
        decimalpart = str2double(longitudeparts{2}{1})/10;
    end
%
    if (str2double(longitudeparts{1}{1}(1:end-2)) > 0)
        testpart3 = str2double(longitudeparts{1}{1}(1:end-2));
        testpart4 = ((str2double(longitudeparts{1}{1}(end-1:end))+decimalpart)/60);
        templon1 = round(10000*(testpart3+testpart4))/10000;
    else
        testpart3 = str2double(longitudeparts{1}{1}(1:end-2));
        testpart4 = ((str2double(longitudeparts{1}{1}(end-1:end))+decimalpart)/60);
        templon1 = round(10000*(testpart3-testpart4))/10000;
    end
%
    if (~isequal(templat1,templat) || ~isequal(templon1,templon))
%
		parts = textscan(temp, '%s %s %s %s %s %s', 'Delimiter', ':');
%    
		divenumber(j) = str2num(parts{1}{1:end});
		calls(j) = str2num(parts{2}{1:end});
		nocomm(j) = str2num(parts{3}{1:end});
%
		parts = textscan(temp, '%s %s %s %s %s %s %s %s %s', 'Delimiter', ',');
%    
		datetime(1,j) = str2num(parts{2}{1}(1:2));
		datetime(2,j) = str2num(parts{2}{1}(3:4));
		datetime(3,j) = 2000+str2num(parts{2}{1}(5:6));
		datetime(4,j) = str2num(parts{3}{1}(1:2));
		datetime(5,j) = str2num(parts{3}{1}(3:4));
		datetime(6,j) = str2num(parts{3}{1}(5:6));
%
%    latitude(j) =  round(10000*(str2num(parts{4}{1}(1:3))-(str2num(parts{4}{1}(4:end))/60)))/10000;
%    longitude(j) =  round(10000*(str2num(parts{5}{1}(1:3))+(str2num(parts{5}{1}(4:end))/60)))/10000;
%
		if (str2double(latitudeparts{1}{1}(1:end-2)) > 0)
			latitude(j) = round(10000*(testpart1+testpart2))/10000;
		else
			latitude(j) = round(10000*(testpart1-testpart2))/10000;
		end
%
		if (str2double(longitudeparts{1}{1}(1:end-2)) > 0)
			longitude(j) = round(10000*(testpart3+testpart4))/10000;
		else
			longitude(j) = round(10000*(testpart3-testpart4))/10000;
		end
%
		j=j+1;
    end
    templat = templat1;
    templon = templon1;
%    
end
%
dimfile =length(latitude);
%CHECK IF A FILE CONTAINING THE POSITIONS OF THE SEAGLIDER HAS ALREADY BEEN
%CREATED
fileinfolder = fullfile(outputdir,processingdir,strcat(deployment,'_position*.txt'));
%
testpos = 0;
try
testpos = length(dir(fileinfolder));
end
%
value_pkid = strcat('(Select pkid from anfog.anfog_realtime_deployment where name = '' ',deployment,''') ' );
if (testpos == 0)
%FIRST TIME THE FILE WILL BE CREATED
    if (~exist(fullfile(outputdir,processingdir),'dir'))
       mkdir(fullfile(outputdir,processingdir));
    end
    fid_w = fopen(fileoutput1,'w');
    for i=1:dimfile    
     fprintf(fid_w,'%s %s %s %s %s %s\n',num2str(divenumber(i)),num2str(calls(i)),num2str(nocomm(i)),num2str(datestr(datenum(datetime(3,i),datetime(2,i),datetime(1,i),datetime(4,i),datetime(5,i),datetime(6,i)))),num2str(latitude(i)),num2str(longitude(i)));
    end
    fclose(fid_w);
%WRITE THE SQL COMMAND IN THE OUTPUT FILE
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
              fprintf(fid_w2,'VALUES (\''%s\'', \''%s\'');\n',deployment,glidertype);
           else
              fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_deployment(name,glider_type,summary_plot)\n');
              fprintf(fid_w2,'VALUES (\''%s\'', \''%s\'',TRUE);\n',deployment,glidertype);
           end
     end
     for i=2:dimfile
        if is_SOTS == 1
    fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_track(fk_anfog_realtime_deployment,dive,call,nocomm,time_start,latitude,longitude, geom)\n');
    fprintf(fid_w2,'VALUES (%s, %s, %s, %s, \''%s\'', %s, %s,LineFromText(\''LINESTRING(',value_pkid,num2str(divenumber(i)),num2str(calls(i)),num2str(nocomm(i)),num2str(datestr(datenum(datetime(3,i),datetime(2,i),datetime(1,i),datetime(4,i),datetime(5,i),datetime(6,i)),'yyyy-mm-ddTHH:MM:SSZ')),num2str(latitude(i)),num2str(longitude(i)));
    fprintf(fid_w2, '%s %s , %s %s)\'',4326));\n',num2str(longitude(i-1)),num2str(latitude(i-1)),num2str(longitude(i)),num2str(latitude(i)));
        else
    fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_track(fk_anfog_realtime_deployment,dive,call,nocomm,time_start,latitude,longitude, geom)\n');
    fprintf(fid_w2,'VALUES (%s, %s, %s, %s, \''%s\'', %s, %s,LineFromText(\''LINESTRING(',value_pkid,num2str(divenumber(i)),num2str(calls(i)),num2str(nocomm(i)),num2str(datestr(datenum(datetime(3,i),datetime(2,i),datetime(1,i),datetime(4,i),datetime(5,i),datetime(6,i)),'yyyy-mm-ddTHH:MM:SSZ')),num2str(latitude(i)),num2str(longitude(i)));
    fprintf(fid_w2, '%s %s , %s %s)\'',4326));\n',num2str(longitude(i-1)),num2str(latitude(i-1)),num2str(longitude(i)),num2str(latitude(i)));
        end
    end
    fclose(fid_w2);   
%
	status = 1;
%
    if ~exist(fullfile(outputdir,archivedir,deployment),'dir');
       mkdir(fullfile(outputdir,archivedir,deployment));
    end
    copyfile(fileoutput2,fileoutput3);
%
else
%THE FILE HAS ALREADY BEEN CREATED
%THE FOLLOWING LINES ARE CHECKING THE DATA ALREADY PROCESSED
%    filename = 'seaglider_realtime_position.txt';
    fid = fopen(fileoutput1);
    C = textscan(fid,'%f %f %f %s %s %f %f');
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
        fprintf(fid_w,'%s %s %s %s %s %s\n',num2str(divenumber(i)),num2str(calls(i)),num2str(nocomm(i)),num2str(datestr(datenum(datetime(3,i),datetime(2,i),datetime(1,i),datetime(4,i),datetime(5,i),datetime(6,i)))),num2str(latitude(i)),num2str(longitude(i)));
        end
        fclose(fid_w);
%WRITE THE SQL COMMAND IN THE OUTPUT FILE
    fid_w2 = fopen(fileoutput2,'w');
    for i=length(C{1})+1:dimfile
        if is_SOTS == 1    
    fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_track(fk_anfog_realtime_deployment,dive,call,nocomm,time_start,latitude,longitude, geom)\n');
    fprintf(fid_w2,'VALUES (%s, %s, %s, %s, \''%s\'', %s, %s,LineFromText(\''LINESTRING(',value_pkid,num2str(divenumber(i)),num2str(calls(i)),num2str(nocomm(i)),num2str(datestr(datenum(datetime(3,i),datetime(2,i),datetime(1,i),datetime(4,i),datetime(5,i),datetime(6,i)),'yyyy-mm-ddTHH:MM:SSZ')),num2str(latitude(i)),num2str(longitude(i)));
    fprintf(fid_w2, '%s %s , %s %s)\'',4326));\n',num2str(longitude(i-1)),num2str(latitude(i-1)),num2str(longitude(i)),num2str(latitude(i)));
        else
    fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_track(fk_anfog_realtime_deployment,dive,call,nocomm,time_start,latitude,longitude, geom)\n');
    fprintf(fid_w2,'VALUES (%s, %s, %s, %s, \''%s\'', %s, %s,LineFromText(\''LINESTRING(',value_pkid,num2str(divenumber(i)),num2str(calls(i)),num2str(nocomm(i)),num2str(datestr(datenum(datetime(3,i),datetime(2,i),datetime(1,i),datetime(4,i),datetime(5,i),datetime(6,i)),'yyyy-mm-ddTHH:MM:SSZ')),num2str(latitude(i)),num2str(longitude(i)));
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
%        delete (fileoutput2)
    end
end
