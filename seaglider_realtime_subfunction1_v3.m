function [toto] = seaglider_realtime_subfunction1_v3(filename,deployment,nbnetcdf)
%filename = 'H:\DATA\ANFOG\realtime\SOTS20100320_comm.log';
%deployment = 'SOTS20100320'
%
global currentdir
global outputdir
%
%Nom du fichier OUTPUT avec les position enregistrees
fileoutput1 = strcat(outputdir,'\processing\',deployment,'_position_seaglider_realtime.txt');
%Fichier d OUTPUT contenant les commandes SQL pour remplir la table de la
%base de donnee
fileoutput2 = strcat(outputdir,'\processing\',deployment,'_SQL_update.txt');
%
%Fichier de sauvegarde
fileoutput3 = strcat(outputdir,'\archive\',deployment,'\',deployment,'_SQL_update_',datestr(clock,'ddmmyyyyTHHMMSSZ'),'.txt');
%Recherche des lignes qui contiennent les caracteres GPS dans le fichier de
%communication. Pour cela on utilise la fonction grep
[Fl,P] = grep('-n',{'GPS'},{filename});
%dimension
dimfile = length(P.match);
%
%Lecture des donnees contenues dans le fichier de communication
%On va conserver les valeurs de 6 variables
%var1: le nombre de plongee
%var2 : le nombre d appels
%var3 : le nombre de communications manquees
%var4 : la date et l heure
%var5 : latitude
%var6 : longitude
%
glidertype = 'Seaglider';
SOTSabstract = 'Australian Bluewater Observing System (ABOS) Slocum Glider deployments run a transect from the Southern Ocean towards Tasmania. Data is transmitted in near-real time to the IMOS ANFOG facility.';
SOTSmetadata = '3e575769-201b-4928-a15d-11ec7e5a7bdd';
%
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
%Lecture ligne apres ligne des donnees
%creation d une variable temporaire
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
%
%On verifie si un fichier contenant les positions du sea glider a deja ete
%cree auparavant
fileinfolder = strcat(outputdir,'\processing\',deployment,'_position*.txt');
%
testpos = 0;
try
testpos = length(dir(fileinfolder));
end
%
value_pkid = strcat('(Select pkid from anfog.anfog_realtime_deployment where name = '' ',deployment,''') ' );
if (testpos == 0)
%premiere fois que le fichier va etre cree
    if (~exist(strcat(outputdir,'\processing'),'dir'))
       mkdir(strcat(outputdir,'\processing'));
    end
    fid_w = fopen(fileoutput1,'w');
    for i=1:dimfile    
     fprintf(fid_w,'%s %s %s %s %s %s\n',num2str(divenumber(i)),num2str(calls(i)),num2str(nocomm(i)),num2str(datestr(datenum(datetime(3,i),datetime(2,i),datetime(1,i),datetime(4,i),datetime(5,i),datetime(6,i)))),num2str(latitude(i)),num2str(longitude(i)));
    end
    fclose(fid_w);
%Permet d ecrire les commandes SQL
    fid_w2 = fopen(fileoutput2,'w');
           switch (deployment)
               case {'SOTS20100320'}
                     if (nbnetcdf == 0)
                   fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_deployment(name,glider_type,abstract,metadata)\n');
                   fprintf(fid_w2,'VALUES (\''%s\'', \''%s\'', \''%s\'', \''%s\'');\n',deployment,glidertype,SOTSabstract,SOTSmetadata);
                     else
                   fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_deployment(name,glider_type,abstract,metadata,summary_plot)\n');
                   fprintf(fid_w2,'VALUES (\''%s\'', \''%s\'', \''%s\'', \''%s\'',TRUE);\n',deployment,glidertype,SOTSabstract,SOTSmetadata);
                     end
               otherwise
                     if (nbnetcdf == 0)
                   fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_deployment(name,glider_type)\n');
                   fprintf(fid_w2,'VALUES (\''%s\'', \''%s\'');\n',deployment,glidertype);
                     else
                   fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_deployment(name,glider_type,summary_plot)\n');
                   fprintf(fid_w2,'VALUES (\''%s\'', \''%s\'',TRUE);\n',deployment,glidertype);
                     end
           end
    for i=2:dimfile
        switch(deployment)
            case {'SOTS20100320'}
    fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_track(fk_anfog_realtime_deployment,dive,call,nocomm,time_start,latitude,longitude, geom)\n');
    fprintf(fid_w2,'VALUES (%s, %s, %s, %s, \''%s\'', %s, %s,LineFromText(\''LINESTRING(',value_pkid,num2str(divenumber(i)),num2str(calls(i)),num2str(nocomm(i)),num2str(datestr(datenum(datetime(3,i),datetime(2,i),datetime(1,i),datetime(4,i),datetime(5,i),datetime(6,i)),'yyyy-mm-ddTHH:MM:SSZ')),num2str(latitude(i)),num2str(longitude(i)));
    fprintf(fid_w2, '%s %s , %s %s)\'',4326));\n',num2str(longitude(i-1)),num2str(latitude(i-1)),num2str(longitude(i)),num2str(latitude(i)));
            otherwise
    fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_track(fk_anfog_realtime_deployment,dive,call,nocomm,time_start,latitude,longitude, geom)\n');
    fprintf(fid_w2,'VALUES (%s, %s, %s, %s, \''%s\'', %s, %s,LineFromText(\''LINESTRING(',value_pkid,num2str(divenumber(i)),num2str(calls(i)),num2str(nocomm(i)),num2str(datestr(datenum(datetime(3,i),datetime(2,i),datetime(1,i),datetime(4,i),datetime(5,i),datetime(6,i)),'yyyy-mm-ddTHH:MM:SSZ')),num2str(latitude(i)),num2str(longitude(i)));
    fprintf(fid_w2, '%s %s , %s %s)\'',4326));\n',num2str(longitude(i-1)),num2str(latitude(i-1)),num2str(longitude(i)),num2str(latitude(i)));
        end
    end
    fclose(fid_w2);   
%
toto = 1;
%
    if (~exist(strcat(outputdir,'\archive\',deployment),'dir'))
       mkdir(strcat(outputdir,'\archive\',deployment));
    end
    copyfile(fileoutput2,fileoutput3);
%
else
%Le fichier a deja ete cree, on utilise les lignes suivantes pour regarder
%les donnees deja enregistrees      
%    filename = 'seaglider_realtime_position.txt';
    fid = fopen(fileoutput1);
    C = textscan(fid,'%f %f %f %s %s %f %f');
    fclose(fid);
%
 toto = 2;   
%
    if (length(C{1})<dimfile)
%
        z=0;
        for i=length(C{1})+1:dimfile
            z=z+1;
        end
%Creation du fichier position remis a jour        
        fid_w = fopen(fileoutput1,'w');
        for i=1:dimfile
        fprintf(fid_w,'%s %s %s %s %s %s\n',num2str(divenumber(i)),num2str(calls(i)),num2str(nocomm(i)),num2str(datestr(datenum(datetime(3,i),datetime(2,i),datetime(1,i),datetime(4,i),datetime(5,i),datetime(6,i)))),num2str(latitude(i)),num2str(longitude(i)));
        end
        fclose(fid_w);
%Permet d ecrire les commandes SQL
    fid_w2 = fopen(fileoutput2,'w');
    for i=length(C{1})+1:dimfile
        switch(deployment)
            case {'SOTS20100320'}   
    fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_track(fk_anfog_realtime_deployment,dive,call,nocomm,time_start,latitude,longitude, geom)\n');
    fprintf(fid_w2,'VALUES (%s, %s, %s, %s, \''%s\'', %s, %s,LineFromText(\''LINESTRING(',value_pkid,num2str(divenumber(i)),num2str(calls(i)),num2str(nocomm(i)),num2str(datestr(datenum(datetime(3,i),datetime(2,i),datetime(1,i),datetime(4,i),datetime(5,i),datetime(6,i)),'yyyy-mm-ddTHH:MM:SSZ')),num2str(latitude(i)),num2str(longitude(i)));
    fprintf(fid_w2, '%s %s , %s %s)\'',4326));\n',num2str(longitude(i-1)),num2str(latitude(i-1)),num2str(longitude(i)),num2str(latitude(i)));
             otherwise
    fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_track(fk_anfog_realtime_deployment,dive,call,nocomm,time_start,latitude,longitude, geom)\n');
    fprintf(fid_w2,'VALUES (%s, %s, %s, %s, \''%s\'', %s, %s,LineFromText(\''LINESTRING(',value_pkid,num2str(divenumber(i)),num2str(calls(i)),num2str(nocomm(i)),num2str(datestr(datenum(datetime(3,i),datetime(2,i),datetime(1,i),datetime(4,i),datetime(5,i),datetime(6,i)),'yyyy-mm-ddTHH:MM:SSZ')),num2str(latitude(i)),num2str(longitude(i)));
    fprintf(fid_w2, '%s %s , %s %s)\'',4326));\n',num2str(longitude(i-1)),num2str(latitude(i-1)),num2str(longitude(i)),num2str(latitude(i)));
        end
    end
    fclose(fid_w2); 
    if (~exist(strcat(outputdir,'\archive\',deployment),'dir'))
       mkdir(strcat(outputdir,'\archive\',deployment));
    end
    copyfile(fileoutput2,fileoutput3);
    else
        toto = 3;
        fid_w2 = fopen(fileoutput2,'w');
        fclose(fid_w2);
%        delete (fileoutput2)
    end
end
