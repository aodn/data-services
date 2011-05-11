function [toto] = slocum_realtime_subfunction1_UNIX_v3(filename,deployment,nbnetcdf)
%filename = 'H:\DATA\ANFOG\realtime\SOTS20100320_comm.log';
%deployment = 'SOTS20100320'
%
global currentdir
global outputdir
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%OUTPUT FILES
%
%Nom du fichier OUTPUT avec les position enregistrees
fileoutput1 = strcat(outputdir,'/processing/',deployment,'_position_slocum_realtime.txt');
%Fichier d OUTPUT contenant les commandes SQL pour remplir la table de la
%base de donnee
fileoutput2 = strcat(outputdir,'/processing/',deployment,'_SQL_update.txt');
%
%Fichier de sauvegarde
fileoutput3 = strcat(outputdir,'/archive/',deployment,'/',deployment,'_SQL_update_',datestr(clock,'ddmmyyyyTHHMMSSZ'),'.txt');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%METADONNES: description de chque nouveau deploiement
%
glidertype = 'Slocum glider';
SOTSabstract = 'Australian Bluewater Observing System (ABOS) Slocum Glider deployments run a transect from the Southern Ocean towards Tasmania. Data is transmitted in near-real time to the IMOS ANFOG facility.';
SOTSmetadata = '3e575769-201b-4928-a15d-11ec7e5a7bdd';
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fid = fopen(filename,'r');
line = fgetl(fid);
data{1} = line;
%creation of the variable i
i=2;
%%
%Read all the data
while line~=-1,
%while i~=1000,
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
    temptime = datevec(datenum('01-01-1970 00:00:00')+(str2num(data{i}(1:indexspace(1)-1)))/60/60/24);
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
%On verifie si un fichier contenant les positions du slocum glider a deja ete
%cree auparavant
fileinfolder = strcat(outputdir,'/processing/',deployment,'_position*.txt');
%
testpos = 0;
try
testpos = length(dir(fileinfolder));
end
%
value_pkid=strcat('(Select pkid from anfog.anfog_realtime_deployment where name ='' ',deployment,''') ' );
if (testpos == 0)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%premiere fois que le fichier va etre cree
    if (~exist(strcat(outputdir,'/processing'),'dir'))
       mkdir(strcat(outputdir,'/processing'));
    end
    fid_w = fopen(fileoutput1,'w');
    for i=1:dimfile    
     fprintf(fid_w,'%s %s %s\n',num2str(datestr(datenum(datetime(1,i),datetime(2,i),datetime(3,i),datetime(4,i),datetime(5,i),datetime(6,i)))),num2str(latitude(i)),num2str(longitude(i)));
    end
    fclose(fid_w);
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
        fprintf(fid_w2,'VALUES (\''%s\'',\''%s\'');\n',deployment,glidertype);    
            else
        fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_deployment(name,glider_type,summary_plot)\n');
        fprintf(fid_w2,'VALUES (\''%s\'',\''%s\'',TRUE);\n',deployment,glidertype);                 
            end
    end
    for i=2:dimfile
        switch(deployment)
            case {'SOTS20100320'}
    fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_track(fk_anfog_realtime_deployment,time_start,latitude,longitude, geom)\n');
    fprintf(fid_w2,'VALUES (%s, \''%s\'', %s, %s,LineFromText(\''LINESTRING(',value_pkid,num2str(datestr(datenum(datetime(1,i),datetime(2,i),datetime(3,i),datetime(4,i),datetime(5,i),datetime(6,i)),'yyyy-mm-ddTHH:MM:SSZ')),num2str(latitude(i)),num2str(longitude(i)));
    fprintf(fid_w2, '%s %s , %s %s)\'',4326));\n',num2str(longitude(i-1)),num2str(latitude(i-1)),num2str(longitude(i)),num2str(latitude(i)));
            otherwise
    fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_track(fk_anfog_realtime_deployment,time_start,latitude,longitude, geom)\n');
    fprintf(fid_w2,'VALUES (%s, \''%s\'', %s, %s,LineFromText(\''LINESTRING(',value_pkid,num2str(datestr(datenum(datetime(1,i),datetime(2,i),datetime(3,i),datetime(4,i),datetime(5,i),datetime(6,i)),'yyyy-mm-ddTHH:MM:SSZ')),num2str(latitude(i)),num2str(longitude(i)));
    fprintf(fid_w2, '%s %s , %s %s)\'',4326));\n',num2str(longitude(i-1)),num2str(latitude(i-1)),num2str(longitude(i)),num2str(latitude(i)));
        end
    end
    fclose(fid_w2);   
%
toto = 1;
%
    if (~exist(strcat(outputdir,'/archive/',deployment),'dir'))
       mkdir(strcat(outputdir,'/archive/',deployment));
    end
    copyfile(fileoutput2,fileoutput3);
%
else
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Le fichier a deja ete cree, on utilise les lignes suivantes pour regarder
%les donnees deja enregistrees      
%    filename = 'seaglider_realtime_position.txt';
    fid = fopen(fileoutput1);
    C = textscan(fid,'%s %s %f %f');
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
        fprintf(fid_w,'%s %s %s\n',num2str(datestr(datenum(datetime(1,i),datetime(2,i),datetime(3,i),datetime(4,i),datetime(5,i),datetime(6,i)))),num2str(latitude(i)),num2str(longitude(i)));
        end
        fclose(fid_w);
%Permet d ecrire les commandes SQL
    fid_w2 = fopen(fileoutput2,'w');
    for i=length(C{1})+1:dimfile
        switch(deployment)
            case {'SOTS20100320'}
    fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_track(fk_anfog_realtime_deployment,time_start,latitude,longitude, geom)\n');
    fprintf(fid_w2,'VALUES (%s, \''%s\'', %s, %s,LineFromText(\''LINESTRING(',value_pkid,num2str(datestr(datenum(datetime(1,i),datetime(2,i),datetime(3,i),datetime(4,i),datetime(5,i),datetime(6,i)),'yyyy-mm-ddTHH:MM:SSZ')),num2str(latitude(i)),num2str(longitude(i)));
    fprintf(fid_w2, '%s %s , %s %s)\'',4326));\n',num2str(longitude(i-1)),num2str(latitude(i-1)),num2str(longitude(i)),num2str(latitude(i)));
            otherwise
    fprintf(fid_w2,'INSERT INTO anfog.anfog_realtime_track(fk_anfog_realtime_deployment,time_start,latitude,longitude, geom)\n');
    fprintf(fid_w2,'VALUES (%s, \''%s\'', %s, %s,LineFromText(\''LINESTRING(',value_pkid,num2str(datestr(datenum(datetime(1,i),datetime(2,i),datetime(3,i),datetime(4,i),datetime(5,i),datetime(6,i)),'yyyy-mm-ddTHH:MM:SSZ')),num2str(latitude(i)),num2str(longitude(i)));
    fprintf(fid_w2, '%s %s , %s %s)\'',4326));\n',num2str(longitude(i-1)),num2str(latitude(i-1)),num2str(longitude(i)),num2str(latitude(i)));
        end
    end
    fclose(fid_w2); 
    if (~exist(strcat(outputdir,'/archive/',deployment),'dir'))
       mkdir(strcat(outputdir,'/archive/',deployment));
    end
    copyfile(fileoutput2,fileoutput3);
    else
        toto = 3;
        fid_w2 = fopen(fileoutput2,'w');
        fclose(fid_w2);
    end
end