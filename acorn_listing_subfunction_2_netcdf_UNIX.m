function [dateforfileSQL] = acorn_listing_subfunction_2_netcdf_UNIX(namefile,site_code,zz)
%
%
for i = 1:12
    data{i} = namefile{i};
end
%
%
temp = datenum(namefile{1}(15:29),'yyyymmddTHHMMSS');
dateforfileSQL = datestr(temp+1/48,'yyyymmddTHHMMSS');
clear temp
%
%File dimension
dimfile = length(data);
%
%la boucle suivante permet de regarder la variable POSITION de 
%tous les fichiers NetCDF presents dans le fichier texte
%et d en sortir la valeur maximale prise par la variable POSITION.
%
maxPOS = 0;
%
for i = 1:dimfile
%    
    nc = netcdf.open(strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',data{i}(32:34),'/',data{i}(15:18),'/',data{i}(19:20),'/',data{i}(21:22),'/',data{i}(1:end-3),'.nc'),'NC_NOWRITE');
    temp_varid = netcdf.inqVarID(nc,'POSITION');
    temp = netcdf.getVar(nc,temp_varid);
    POS = temp(:);
%
    maxtemp = max(POS);
    if ( maxtemp>maxPOS)
        maxPOS=maxtemp;
    end
    netcdf.close(nc)
end
%
%Creation de 2 matrices qui permettront de stocker l ensemble des donnees
%disponibles dans chacun des fichiers NetCDF
%Les deux matrices sont remplies de NaN au depart
%
station1 = NaN(maxPOS,9,7);
station2 = NaN(maxPOS,9,7);
%
%Remplissage des valeurs pour la premiere station
t=1;
for i = 1:2:dimfile
    nc = netcdf.open(strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',data{i}(32:34),'/',data{i}(15:18),'/',data{i}(19:20),'/',data{i}(21:22),'/',data{i}(1:end-3),'.nc'),'NC_NOWRITE');
    temp_varid = netcdf.inqVarID(nc,'POSITION');
    temp = netcdf.getVar(nc,temp_varid);
    POS = temp(:);
    dimtemp = length(POS);
%
    temp_varid = netcdf.inqVarID(nc,'LONGITUDE');
    temp = netcdf.getVar(nc,temp_varid);
    lon = temp(:);
    temp_varid = netcdf.inqVarID(nc,'LATITUDE');
    temp = netcdf.getVar(nc,temp_varid);
    lat = temp(:);
    temp_varid = netcdf.inqVarID(nc,'ssr_Surface_Radial_Sea_Water_Speed');
    temp = netcdf.getVar(nc,temp_varid);
    speed = temp(:);
    temp_varid = netcdf.inqVarID(nc,'ssr_Surface_Radial_Direction_Of_Sea_Water_Velocity');
    temp = netcdf.getVar(nc,temp_varid);
    dir = temp(:);
%
    tmpglobalattr = netcdf.getatt(nc,netcdf.getConstant('GLOBAL'),'time_coverage_start');
    timestampseb{i} = tmpglobalattr(1:end);
    netcdf.close(nc)
%    
%global_attr=loaddap('-A', qcif_url);
%timestampseb{i} = global_attr.Global_Attributes.NC_GLOBAL.time_coverage_start(2:end-1);
%
%Acces des donnees pour la variable Standard Error
    nc = netcdf.open(strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',data{i}(32:34),'/',data{i}(15:18),'/',data{i}(19:20),'/',data{i}(21:22),'/',data{i}(1:end-3),'.nc'),'NC_NOWRITE');
    temp_varid = netcdf.inqVarID(nc,'ssr_Surface_Radial_Sea_Water_Speed_Standard_Error');
    temp = netcdf.getVar(nc,temp_varid);
    error = temp(:);
%
    temp_varid = netcdf.inqVarID(nc,'ssr_Bragg_Signal_To_Noise');
    temp = netcdf.getVar(nc,temp_varid);
    bragg = temp(:);
    netcdf.close(nc)
%
%Creation de la variable station1
%variable 1 : POSITION
%variable 2 : LATITUDE
%variable 3 : LONGITUDE
%variable 4 : VITESSE (Cette valeur peut etre positif [courant s ecartant
%de la station radar] ou negative [ courant se rapprochant de la station radar])
%variable 5 : DIRECTION (valeur calcule entre la station radar et le point
%de grille)
%variable 6 : Composante U de la vitesse (calcule a aprtir de Speed et
%direction
%variable 7 : Composante V de la vitesse (calcule a aprtir de Speed et
%direction
%variable 8 : STANDARD ERROR de la vitesse du courant
    for j=1:dimtemp
        station1(POS(j),1,t) = POS(j);
        station1(POS(j),2,t) = lon(j);
        station1(POS(j),3,t) = lat(j);
        station1(POS(j),4,t) = speed(j);
        station1(POS(j),5,t) = dir(j);
%
%On calcule les composantes u et v du vecteur radial
%
        station1(POS(j),6,t) = speed(j)*sin(dir(j)*pi/180);
        station1(POS(j),7,t) = speed(j)*cos(dir(j)*pi/180);
%Donnees d erreur sur la vitesse du courant
        station1(POS(j),8,t) = error(j);
%Donnees du Bragg ratio
        station1(POS(j),9,t) = bragg(j);
%
    end
    t=t+1;
end
clear POS lat lon speed dir
%
%Recherche des points de grille dont la valeur de la norme de la vitesse 
%est superieure a une certaine valeur. 
%Pour chacune des variables de ces points de grille, on remplace les
%valeurs par des NaN
%
%maxnorme = 1;
%for i=1:6
%I = find(abs(station1(:,4,i))>maxnorme);
%station1(I,:,i) = NaN;
%end
%
%BRAGG CRITERIA
for i=1:6
K = find(station1(:,9,i)<8);
station1(K,:,i) = NaN;
end
%
%STANDARD ERROR CRITERIA
%for i=1:6
%K = find((abs(station1(:,4,i))./station1(:,8,i))<1);
%station1(K,:,i) = NaN;
%end
%
%NUMBER OF VALID RADIALS CRITERIA
for i=1:maxPOS
checkradial(i) = sum(~isnan(station1(i,4,1:6)));
end
J = find(checkradial<3);
station1(J,:,:) = NaN;
station2(J,:,:) = NaN;
clear checkradial J
%
%
%Remplissage des valeurs pour la deuxieme station
%
t=1;
for i = 2:2:dimfile
    nc = netcdf.open(strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',data{i}(32:34),'/',data{i}(15:18),'/',data{i}(19:20),'/',data{i}(21:22),'/',data{i}(1:end-3),'.nc'),'NC_NOWRITE');
    temp_varid = netcdf.inqVarID(nc,'POSITION');
    temp = netcdf.getVar(nc,temp_varid);
    POS = temp(:);
    dimtemp = length(POS);
%
    temp_varid = netcdf.inqVarID(nc,'LONGITUDE');
    temp = netcdf.getVar(nc,temp_varid);
    lon = temp(:);
    temp_varid = netcdf.inqVarID(nc,'LATITUDE');
    temp = netcdf.getVar(nc,temp_varid);
    lat = temp(:);
    temp_varid = netcdf.inqVarID(nc,'ssr_Surface_Radial_Sea_Water_Speed');
    temp = netcdf.getVar(nc,temp_varid);
    speed = temp(:);
    temp_varid = netcdf.inqVarID(nc,'ssr_Surface_Radial_Direction_Of_Sea_Water_Velocity');
    temp = netcdf.getVar(nc,temp_varid);
    dir = temp(:);
%
    tmpglobalattr = netcdf.getatt(nc,netcdf.getConstant('GLOBAL'),'time_coverage_start');
    timestampseb{i} = tmpglobalattr(1:end);
    netcdf.close(nc)
%    
%global_attr=loaddap('-A', qcif_url);
%timestampseb{i} = global_attr.Global_Attributes.NC_GLOBAL.time_coverage_start(2:end-1);
%
%Acces des donnees pour la variable Standard Error
    nc = netcdf.open(strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',data{i}(32:34),'/',data{i}(15:18),'/',data{i}(19:20),'/',data{i}(21:22),'/',data{i}(1:end-3),'.nc'),'NC_NOWRITE');
    temp_varid = netcdf.inqVarID(nc,'ssr_Surface_Radial_Sea_Water_Speed_Standard_Error');
    temp = netcdf.getVar(nc,temp_varid);
    error = temp(:);
%
    temp_varid = netcdf.inqVarID(nc,'ssr_Bragg_Signal_To_Noise');
    temp = netcdf.getVar(nc,temp_varid);
    bragg = temp(:);
    netcdf.close(nc)
%
%
    for j=1:dimtemp
        station2(POS(j),1,t) = POS(j);
        station2(POS(j),2,t) = lon(j);
        station2(POS(j),3,t) = lat(j);
        station2(POS(j),4,t) = speed(j);
        station2(POS(j),5,t) = dir(j);
%composante u et v de la vitesse        
        station2(POS(j),6,t) = speed(j)*sin(dir(j)*pi/180);
        station2(POS(j),7,t) = speed(j)*cos(dir(j)*pi/180);
%Donnees d erreur sur la vitesse du courant
        station2(POS(j),8,t) = error(j);
%Donnees du Bragg ratio
        station2(POS(j),9,t) = bragg(j);        
    end
    t=t+1;
end
%Recherche des points de grille dont la valeur de la norme de la vitesse 
%est superieure a une certaine valeur. 
%Pour chacune des variables de ces points de grille, on remplace les
%valeurs par des NaN
%
%for i=1:6
%I = find(abs(station2(:,4,i))>maxnorme);
%station2(I,:,i) = NaN;
%end
%
%BRAGG CRITERIA
for i=1:6
K = find(station2(:,9,i)<8);
station2(K,:,i) = NaN;
end
%
%STANDARD ERROR CRITERIA
%for i=1:6
%K = find((abs(station2(:,4,i))./station2(:,8,i))<1);
%station2(K,:,i) = NaN;
%end
%
%NUMBER OF VALID RADIALS CRITERIA
for i=1:maxPOS
checkradial(i) = sum(~isnan(station2(i,4,1:6)));
end
J = find(checkradial<3);
station2(J,:,:) = NaN;
station1(J,:,:) = NaN;
clear checkradial J
%
%Calcul de la moyenne de chacune des variables
%On calcule la moyenne de chacune des deux composantes (u et v) du vecteur 
%radial. par la suite on utilise ces moyennes pour retrouver la valeur 
%moyenne de la vitesse et la valeur moyenne de la direction pour
%chacun des points de grill et pour chaque station.
%C est grace aux deux vecteurs radiales moyennes sur 1 heure qu il sera par la suite
%possible de calculer le vecteur resultant
%
%
for i=1:maxPOS
    for j=1:9
        station1(i,j,7) = nanmean(station1(i,j,1:6));
        station2(i,j,7) = nanmean(station2(i,j,1:6));
    end
%Calcul de la norme de la vitesse a partir des composantes u et v
%station 1
    station1(i,4,7) = sqrt(station1(i,6,7)*station1(i,6,7)+station1(i,7,7)*station1(i,7,7));
%station 2
    station2(i,4,7) = sqrt(station2(i,6,7)*station2(i,6,7)+station2(i,7,7)*station2(i,7,7));
%Calcul de l angle a partir des composantes u et v
%il faut faire attention dans quel cadran on se trouve car cela va changer
%la valeur de l angle calcule par rapport au Nord.
%
%station1
    station1(i,5,7) = abs(atan(station1(i,6,7)/station1(i,7,7))*180/pi);
%
    if (station1(i,6,7) == 0 && station1(i,7,7) > 0)
        station1(i,5,7) = 0;
            elseif (station1(i,6,7) == 0 && station1(i,7,7) < 0)
        station1(i,5,7) = 180;
            elseif (station1(i,7,7) == 0 && station1(i,6,7) > 0)
        station1(i,5,7) = 90;
            elseif (station1(i,7,7) == 0 && station1(i,6,7) < 0)
        station1(i,5,7) = 270;
            elseif (station1(i,6,7) > 0 && station1(i,7,7) > 0)
        station1(i,5,7) = station1(i,5,7);
            elseif (station1(i,6,7) > 0 && station1(i,7,7) < 0)
        station1(i,5,7) = 180 - station1(i,5,7);
            elseif (station1(i,6,7) < 0 && station1(i,7,7) < 0)
        station1(i,5,7) = 180 + station1(i,5,7);
    else
        station1(i,5,7) = 360 - station1(i,5,7);
    end
%station 2
    station2(i,5,7) = abs(atan(station2(i,6,7)/station2(i,7,7))*180/pi);
%
    if (station2(i,6,7) == 0 && station2(i,7,7) > 0)
        station2(i,5,7) = 0;
            elseif (station2(i,6,7) == 0 && station2(i,7,7) < 0)
        station2(i,5,7) = 180;
            elseif (station2(i,7,7) == 0 && station2(i,6,7) > 0)
        station2(i,5,7) = 90;
            elseif (station2(i,7,7) == 0 && station2(i,6,7) < 0)
        station2(i,5,7) = 270;
            elseif (station2(i,6,7) > 0 && station2(i,7,7) > 0)
        station2(i,5,7) = station2(i,5,7);
            elseif (station2(i,6,7) > 0 && station2(i,7,7) < 0)
        station2(i,5,7) = 180 - station2(i,5,7);
            elseif (station2(i,6,7) < 0 && station2(i,7,7) < 0)
        station2(i,5,7) = 180 + station2(i,5,7);
    else
        station2(i,5,7) = 360 - station2(i,5,7);
    end
%
end
%
%
%Calcul pour chacun des points de grill du vecteur resultant en fonction
%des 2 composantes radiales.
%utilisation de la formule trouvee dans l'article sur Internet
%
k=1;
for i =1:maxPOS
     for j=1:maxPOS
%Verification si les donnees existent au meme point de grille pour les deux stations          
         if (station1(i,1,7) == station2(j,1,7))
%LONGITUDE             
            final(k,1)=station1(i,2,7);
%LATITUDE            
         final(k,2)=station1(i,3,7);
%POSITION         
         final(k,7)=station1(i,1,7);
%EASTWARD COMPONENT OF THE VELOCITY         
  final(k,3)=(station1(i,4,7)*cos(station2(j,5,7)*pi/180)-station2(j,4,7)*cos(station1(i,5,7)*pi/180))/sin((station1(i,5,7)-station2(j,5,7))*pi/180);
%NORTHWARD COMPONENT OF THE VELOCITY
  final(k,4)=(-1*station1(i,4,7)*sin(station2(j,5,7)*pi/180)+station2(j,4,7)*sin(station1(i,5,7)*pi/180))/sin((station1(i,5,7)-station2(j,5,7))*pi/180);
%NORME DE LA VITESSE
  final(k,5)=sqrt(final(k,3)*final(k,3)+final(k,4)*final(k,4));
%EASTWARD COMPONENT  OF THE STANDARD ERROR OF THE VELOCITY
  final(k,8)=(station1(i,8,7)*cos(station2(j,5,7)*pi/180)-station2(j,8,7)*cos(station1(i,5,7)*pi/180))/sin((station1(i,5,7)-station2(j,5,7))*pi/180);
%NORTHWARD COMPONENT OF THE STANDARD ERROR OF THE VELOCITY
  final(k,9)=(-1*station1(i,8,7)*sin(station2(j,5,7)*pi/180)+station2(j,8,7)*sin(station1(i,5,7)*pi/180))/sin((station1(i,5,7)-station2(j,5,7))*pi/180);
%NORME DE LA STANDARD ERROR DE LA VITESSE
  final(k,10)=sqrt(final(k,8)*final(k,8)+final(k,9)*final(k,9));
%RATIO ENTRE LES NORMES DE LA STANDARD ERROR ET LA VITESSE
  final(k,11) = final(k,10)/final(k,5);
%CORRESPONDING BRAGG RATIO OF STATION 1
  final(k,12) = station1(i,9,7);
%CORRESPONDING BRAGG RATIO OF STATION 2  
  final(k,13) = station2(i,9,7);
%  
         k=k+1;
         end
     end
end
%
dimfinal = k-1;
%
%CALCULATION OF THE DIRECTION OF THE CURRENT SPEED
for k=1:dimfinal
    final(k,6) = abs(atan(final(k,3)/final(k,4))*180/pi);
%
    if (final(k,3) == 0 && final(k,4) > 0)
        final(k,6) = 0;
            elseif (final(k,3) == 0 && final(k,4) < 0)
        final(k,6) = 180;
            elseif (final(k,4) == 0 && final(k,3) > 0)
        final(k,6) = 90;
            elseif (final(k,4) == 0 && final(k,3) < 0)
        final(k,6) = 270;
            elseif (final(k,3) > 0 && final(k,4) > 0)
        final(k,6) = final(k,6);
            elseif (final(k,3) > 0 && final(k,4) < 0)
        final(k,6) = 180 - final(k,6);
            elseif (final(k,3) < 0 && final(k,4) < 0)
        final(k,6) = 180 + final(k,6);
    else
        final(k,6) = 360 - final(k,6);
    end
end
%
%Recherche des points de grille dont la valeur de la norme de la vitesse 
%est superieure a une certaine valeur. 
%Pour chacune des variables de ces points de grille, on remplace les
%valeurs par des NaN
%
%I = find(final(:,5)>1.5);
%final(I,3:6) = NaN;
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%NETCDF OUTPUT
%
%
%
switch site_code
    case {'SAG','CWI','CSP'}
%LATITUDE VALUE OF THE GRID       
        fid = fopen('/home/smancini/matlab_seb/ACORN/LAT_SAG.dat','r');
        line=fgetl(fid);
        datalat{1} = line ;
        i=2;
        while line~=-1,
          line=fgetl(fid);
          datalat{i} = line ;
          i=i+1;
        end
        dimlat = length(datalat);
        %
        for i = 1:dimlat-1
            Y(i) = str2num(datalat{i})
        end
%LONGITUDE VALUE OF THE GRID
        fid = fopen('/home/smancini/matlab_seb/ACORN/LON_SAG.dat','r');
        line=fgetl(fid);
        datalon{1} = line ;
        i=2;
        while line~=-1,
          line=fgetl(fid);
          datalon{i} = line ;
          i=i+1;
        end
        dimlon = length(datalon);
        %
        for i = 1:dimlon-1
            X(i) = str2num(datalon{i})
        end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
       case {'GBR','TAN','LEI'}
%LATITUDE VALUE OF THE GRID       
%        fid = fopen('/home/smancini/matlab_seb/ACORN/LAT_GBR.dat','r');
        fid = fopen('/home/smancini/matlab_seb/ACORN/LAT_GBR_grid022011.dat','r');
        line=fgetl(fid);
        datalat{1} = line ;
        i=2;
        while line~=-1,
          line=fgetl(fid);
          datalat{i} = line ;
          i=i+1;
        end
        dimlat = length(datalat);
        %
        for i = 1:dimlat-1
            Y(i) = str2num(datalat{i})
        end
%LONGITUDE VALUE OF THE GRID
%        fid = fopen('/home/smancini/matlab_seb/ACORN/LON_GBR.dat','r');
        fid = fopen('/home/smancini/matlab_seb/ACORN/LON_GBR_grid022011.dat','r');
        line=fgetl(fid);
        datalon{1} = line ;
        i=2;
        while line~=-1,
          line=fgetl(fid);
          datalon{i} = line ;
          i=i+1;
        end
        dimlon = length(datalon);
        %
        for i = 1:dimlon-1
            X(i) = str2num(datalon{i})
        end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
        case {'PCY','FRE','GUI'}
%LATITUDE VALUE OF THE GRID       
        fid = fopen('/home/smancini/matlab_seb/ACORN/LAT_PCY.dat','r');
        line=fgetl(fid);
        datalat{1} = line ;
        i=2;
        while line~=-1,
          line=fgetl(fid);
          datalat{i} = line ;
          i=i+1;
        end
        dimlat = length(datalat);
        %
        for i = 1:dimlat-1
            Y(i) = str2num(datalat{i})
        end
%LONGITUDE VALUE OF THE GRID
        fid = fopen('/home/smancini/matlab_seb/ACORN/LON_PCY.dat','r');
        line=fgetl(fid);
        datalon{1} = line ;
        i=2;
        while line~=-1,
          line=fgetl(fid);
          datalon{i} = line ;
          i=i+1;
        end
        dimlon = length(datalon);
        %
        for i = 1:dimlon-1
            X(i) = str2num(datalon{i})
        end
end
%
%
comptlon = length(X);
comptlat = length(Y);
%
Zrad = NaN(comptlat,comptlon);
Urad = NaN(comptlat,comptlon);
Vrad = NaN(comptlat,comptlon);
%
for i = 1:length(final(:,1))
    index = final(i,7);
    indexj = floor((index-1)/comptlat)+1;
    if (~mod(index,comptlat))
        indexi = comptlat;
    else
        indexi = mod(index,comptlat);
    end
    Zrad(indexi,indexj) = final(i,5);
    Urad(indexi,indexj) = final(i,3);
    Vrad(indexi,indexj) = final(i,4);
end
%
%NetCDF file creation
%
%
Urad(isnan(Urad)) = 9999;
Vrad(isnan(Vrad)) = 9999;
Zrad(isnan(Zrad)) = 9999;
%
timestart = [1950, 1, 1, 0, 0, 0];
%timefin = [2008, 9, 1, 0, 0, 0];
timefin = [str2num(data{1}(15:18)),str2num(data{1}(19:20)),str2num(data{1}(21:22)),str2num(data{1}(24:25)),str2num(data{1}(26:27)),str2num(data{1}(28:29))];
timenc = (etime(timefin,timestart))/(60*60*24);
%
switch site_code
    case {'SAG','CWI','CSP'}
%        pathoutput = '/home/smancini/matlab_seb/ACORN/SAG/';
        pathoutput = '/usr/local/emii/data/matlab/ACORN/SAG/';
    case {'GBR','TAN','LEI'}
%        pathoutput = '/home/smancini/matlab_seb/ACORN/GBR/';
        pathoutput = '/usr/local/emii/data/matlab/ACORN/GBR/';
    case {'PCY','FRE','GUI'}
%        pathoutput = '/home/smancini/matlab_seb/ACORN/PCY/';
        pathoutput = '/usr/local/emii/data/matlab/ACORN/PCY/';
 end
%
netcdfoutput = strcat(pathoutput,'IMOS_ACORN_V_',dateforfileSQL,'_',site_code,'_FV00_1-hour-avg.nc');
%
nc = netcdf.create(netcdfoutput,'NC_CLOBBER');
%
%Creation of the GLOBAL ATTRIBUTES
%
%WHAT
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'project','Integrated Marine Observing System (IMOS)');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'conventions','CF-1.4');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'institution','Australian Coastal Ocean Radar Network');
%
switch site_code
    case {'SAG','CWI','CSP'}
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'title',strcat('IMOS ACORN South Australia Gulf (SAG), one hour averaged current data, ',datestr(timenc(1)+datenum(timestart),'yyyy-mm-ddTHH:MM:SSZ')));    
    case {'GBR','TAN','LEI'}
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'title',strcat('IMOS ACORN Great Barrier Reef (GBR), one hour averaged current data, ',datestr(timenc(1)+datenum(timestart),'yyyy-mm-ddTHH:MM:SSZ')));    
    case {'PCY','FRE','GUI'}
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'title',strcat('IMOS ACORN Perth Canyon (PCY), one hour averaged current data, ',datestr(timenc(1)+datenum(timestart),'yyyy-mm-ddTHH:MM:SSZ')));    
end
%
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'date_created',datestr(clock,'yyyy-mm-ddTHH:MM:SSZ'));
%
netcdfabstract = [''];
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'abstract',netcdfabstract);
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'source','WERA Oceanographic HF Radar/Helzel Messtechnik, GmbH');
acornkeywords = ['Oceans'];
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'keywords',acornkeywords);
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'netcdf_version','3.6');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'naming_authority','IMOS');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'quality_control_set','1');
%WHERE
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_min',min(Y));
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_max',max(Y));
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lon_min',min(X));
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lon_max',max(X));
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_vertical_min',0);
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_vertical_max',0);
%WHEN
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'time_coverage_start',datestr(timenc(1)+datenum(timestart),'yyyy-mm-ddTHH:MM:SSZ'));
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'time_coverage_end',datestr(timenc(1)+datenum(timestart),'yyyy-mm-ddTHH:MM:SSZ'));
%WHO
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'data_centre_email','info@emii.org.au');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'data_centre','eMarine Information Infrastructure (eMII)');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'author','Mancini, Sebastien');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'author_email','info@emii.org.au');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'institution_references','http://www.imos.org.au/acorn.html');
%HOW
acorncitation = [' The citation in a list of references is:'...
    ' IMOS, [year-of-data-download], [Title], [data-access-URL], accessed [date-of-access]'];
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'citation',acorncitation);
acornacknowledgment = ['IMOS is supported by the Australian Government'...
    ' through the National Collaborative Research Infrastructure'...
    ' Strategy (NCRIS) and the Super Science Initiative (SSI). This data was collected by the Environmental Protection Authority (EPA) of Victoria.'...
    ' Assistance with logistical and technical support for this project'...
    ' has been provided by the Spirit of Tasmania 1 vessel operator, TT lines'];
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'acknowledgment',acornacknowledgment);
acorndistribution = ['Data, products and services'...
    ' from IMOS are provided "as is" without any warranty as to fitness'...
    ' for a particular purpose'];
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'distribution_statement',acorndistribution);
acorncomment = ['These data have not been quality controlled.'...
    ' The ACORN facility is producing NetCDF files with radials data for each station every ten minutes. '...
    ' The radial values have been calculated using software provided '...
    ' by the manufacturer of the instrument.'...
    ' eMII is using a Matlab program to read all the netcdf files with radial data for two different stations '...
    ' and produce a one hour average product with U and V components '...
    ' of the current. The final product is produced on a regular geographic (latitude longitude) grid'];
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'comment',acorncomment);
%
%
%Creation of the DIMENSION
%
      TIME_dimid = netcdf.defdim(nc,'TIME',1);
      LATITUDE_dimid = netcdf.defdim(nc,'LATITUDE',comptlat);
      LONGITUDE_dimid = netcdf.defdim(nc,'LONGITUDE',comptlon);
%
%Creation of the VARIABLES
%
TIME_id = netcdf.defVar(nc,'TIME','double',TIME_dimid);
LATITUDE_id = netcdf.defVar(nc,'LATITUDE','double',LATITUDE_dimid);
LONGITUDE_id = netcdf.defVar(nc,'LONGITUDE','double',LONGITUDE_dimid);
SPEED_id = netcdf.defVar(nc,'SPEED','double',[LONGITUDE_dimid,LATITUDE_dimid,TIME_dimid]);
UCUR_id = netcdf.defVar(nc,'UCUR','double',[LONGITUDE_dimid,LATITUDE_dimid,TIME_dimid]);
VCUR_id = netcdf.defVar(nc,'VCUR','double',[LONGITUDE_dimid,LATITUDE_dimid,TIME_dimid]);
%
%Creation of the VARIABLE ATTRIBUTES
%
%Time
      netcdf.putatt(nc,TIME_id,'standard_name','time');
      netcdf.putatt(nc,TIME_id,'long_name','analysis_time');
      netcdf.putatt(nc,TIME_id,'units','days since 1950-01-01 00:00:00');
      netcdf.putatt(nc,TIME_id,'axis','T');
      netcdf.putatt(nc,TIME_id,'valid_min',0);
      netcdf.putatt(nc,TIME_id,'valid_max',999999);
      netcdf.putatt(nc,TIME_id,'_FillValue',-9999);
%Latitude
      netcdf.putatt(nc,LATITUDE_id,'standard_name','latitude');
      netcdf.putatt(nc,LATITUDE_id,'long_name','latitude');
      netcdf.putatt(nc,LATITUDE_id,'units','degrees_north');
      netcdf.putatt(nc,LATITUDE_id,'axis','Y');
      netcdf.putatt(nc,LATITUDE_id,'valid_min',-90);
      netcdf.putatt(nc,LATITUDE_id,'valid_max',90);
      netcdf.putatt(nc,LATITUDE_id,'_FillValue',9999);
      netcdf.putatt(nc,LATITUDE_id,'reference_datum','geographical coordinates, WGS84 projection');
%Longitude
      netcdf.putatt(nc,LONGITUDE_id,'standard_name','longitude');
      netcdf.putatt(nc,LONGITUDE_id,'long_name','longitude');
      netcdf.putatt(nc,LONGITUDE_id,'units','degrees_east');
      netcdf.putatt(nc,LONGITUDE_id,'axis','X');
      netcdf.putatt(nc,LONGITUDE_id,'valid_min',-180);
      netcdf.putatt(nc,LONGITUDE_id,'valid_max',180);
      netcdf.putatt(nc,LONGITUDE_id,'_FillValue',9999);
      netcdf.putatt(nc,LONGITUDE_id,'reference_datum','geographical coordinates, WGS84 projection');
%Current speed
      netcdf.putatt(nc,SPEED_id,'standard_name','sea_water-speed');
      netcdf.putatt(nc,SPEED_id,'long_name','sea water speed');
      netcdf.putatt(nc,SPEED_id,'units','m s-1');
      netcdf.putatt(nc,SPEED_id,'_FillValue',9999);
%Eastward component of the Current speed
      netcdf.putatt(nc,UCUR_id,'standard_name','eastward_sea_water_velocity');
      netcdf.putatt(nc,UCUR_id,'long_name','sea water velocity U component');
      netcdf.putatt(nc,UCUR_id,'units','m s-1');
      netcdf.putatt(nc,UCUR_id,'_FillValue',9999);
%Northward component of the Current speed
      netcdf.putatt(nc,VCUR_id,'standard_name','northward_sea_water_velocity');
      netcdf.putatt(nc,VCUR_id,'long_name','sea water velocity V component');
      netcdf.putatt(nc,VCUR_id,'units','m s-1');
      netcdf.putatt(nc,VCUR_id,'_FillValue',9999);
%
      netcdf.endDef(nc)
%
%Data values for each variable
%
%
      netcdf.putVar(nc,TIME_id,timenc(:));
      netcdf.putVar(nc,LATITUDE_id,Y(:));
      netcdf.putVar(nc,LONGITUDE_id,X(:));
  for tt = 1:comptlon
      for ww = 1:comptlat
      netcdf.putVar(nc,SPEED_id,[tt-1,ww-1,0],[1,1,1],round(Zrad(ww,tt)*100000)/100000);
      netcdf.putVar(nc,UCUR_id,[tt-1,ww-1,0],[1,1,1],round(Urad(ww,tt)*100000)/100000);
      netcdf.putVar(nc,VCUR_id,[tt-1,ww-1,0],[1,1,1],round(Vrad(ww,tt)*100000)/100000);
      end
  end
%
%
%Close the second NetCDF file
	netcdf.close(nc);
%
% switch site_code
%     case {'SAG','CWI','CSP'}
%         pathobs = 'Z:\ACORN_radar\SAG\';
%     case {'GBR','TAN','LEI'}
%         pathobs = 'Z:\ACORN_radar\GBR\';
%     case {'PCY','FRE','GUI'}
%         pathobs = 'Z:\ACORN_radar\PCY\';
%  end
% %
% copyfile(netcdfoutput,pathobs)
%
%
%%partie qui correspond a quiverc
%alpha = 0.4;
%beta = 0.3;
%autoscale =1;
%%
%if min(size(final(:,1)))==1, n=sqrt(prod(size(final(:,1)))); m=n; else [m,n]=size(final(:,1)); end
%%
%delx = diff([min(final(:,1)) max(final(:,1))])/n;
%dely = diff([min(final(:,2)) max(final(:,2))])/m;
%%
%len = sqrt((final(:,3).^2 + final(:,4).^2)/(delx.^2 + dely.^2));
%autoscale = autoscale*0.9 / max(len(:));
%final(:,3) = final(:,3)*autoscale; final(:,4) = final(:,4)*autoscale;
%%
%%
%%----------------------------------------------
%% Define colormap 
%vr=sqrt(final(:,3).^2+final(:,4).^2);
%%
%vrnge = round(vr/max(vr(:))*64);
%%
%CCge = {'000000';
%       '7f0000';
%        '8f0000';
%        '9f0000';
%        'af0000';
%        'bf0000';
%        'cf0000';
%        'df0000';
%       'ef0000';
%        'ff0000';
%        'ff1000';
%        'ff1f00';
%        'ff2f00';
%        'ff3f00';
%        'ff4f00';
%        'ff5f00';
%        'ff6f00';
%        'ff7f00';
%        'ff8f00';
%        'ff9f00';
%        'ffaf00';
%        'ffbf00';
%        'ffcf00';
%        'ffdf00';
%        'ffef00';
%        'ffff00';
%        'efff10';
%        'dfff1f';
%        'cfff2f';
%        'bfff3f';
%        'afff4f';
%        '9fff5f';
%        '8fff6f';
%        '7fff7f';
%        '6fff8f';
%        '5fff9f';
%        '4fffaf';
%        '3fffbf';
%        '2fffcf';
%        '1fffdf';
%        '0fffef';
%        '00ffff';
%        '00efff';
%        '00dfff';
%        '00cfff';
%        '00bfff';
%        '00afff';
%        '0090ff';
%        '0080ff';
%        '0070ff';
%        '0060ff';
%        '0050ff';
%        '0040ff';
%        '0030ff';
%        '0020ff';
%        '0010ff';
%        '0000ff';
%        '0000ef';
%        '0000df';
%        '0000cf';
%        '0000bf';
%        '0000af';
%        '00009f';
%        '00008f';};
%
%%----------------------------------------------
%% Make velocity vectors and plot them
%
%x = final(:,1).';y = final(:,2).';
%px = final(:,3).';py = final(:,4).';
%%
%normvitge = vr.';
%%
%vrnge=vrnge(:).';
%uu = [x;x+px;repmat(NaN,size(px))];
%vv = [y;y+py;repmat(NaN,size(px))];
%vrn1ge= [vrnge;repmat(NaN,size(px));repmat(NaN,size(px))];
%%
%uui=uu(:);
%vvi=vv(:);
%vrn1ge = vrn1ge(:);
%%----------------------------------------------
%% Make arrow heads and plot them
%  hu = [x+px-alpha*(px+beta*(py+eps));x+px; ...
%        x+px-alpha*(px-beta*(py+eps));repmat(NaN,size(px))];
%  hv = [y+py-alpha*(py-beta*(px+eps));y+py; ...
%        y+py-alpha*(py+beta*(px+eps));repmat(NaN,size(py))];
%%
%uui2=hu(:);
%vvi2=hv(:);
%imax=size(uui);
%%
%%PArtie du code modifie par SEB
%%Pour que la fleche soit representee par un polygone et non plus par une
%%ligne , il nous manque les coordonnees de 4 points supplementaires.
%%
%ju = [x+px-alpha*(px+0.1*beta*(py+eps));x+px-alpha*(px-0.1*beta*(py+eps)); ...
%      x+x+px-alpha*(px+0.1*beta*(py+eps))-(x+px-px*alpha); ...
%      x+x+px-alpha*(px-0.1*beta*(py+eps))-(x+px-px*alpha);repmat(NaN,size(px))];
%jv = [y+py-alpha*(py-0.1*beta*(px+eps));y+py-alpha*(py+0.1*beta*(px+eps)); ...
%      y+y+py-alpha*(py-0.1*beta*(px+eps))-(y+py-py*alpha); ...
%      y+y+py-alpha*(py+0.1*beta*(px+eps))-(y+py-py*alpha);repmat(NaN,size(py))];
%%
%uui3=ju(:);
%vvi3=jv(:);
%%
%%
%%CREATE A TEXT FILE CONTAINING SQL COMMAND
%%INCLUDE DATA INOT THE GEOSPATIAL DATABASE
%%
%%fileoutput = strcat(parts{1}{1},'_',parts{2}{1},'_output_SQL-command.sql');
%%fileoutput = strcat(site_code,'_',dateforfileSQL,'_output_SQL_command.sql');
%fileoutput = strcat('/home/smancini/matlab_seb/ACORN/',site_code,'_output_SQL_command.sql');
%%
%%fid_w = fopen('acorn_sql_v4_poly_sequence.txt','w');
%if (zz == 1)
%    fid_w = fopen(fileoutput,'w');
%else
%    fid_w = fopen(fileoutput,'a');
%end
%%
%%
%%site_code = 'PCY';
%%
%%timestampseb = '2009-10-11 01:00:00';
%%
%checkseb = isnan(vr);
%%
%zz=1;
%for row=1:imax/3-1
%    if (checkseb(row) == 0)
%%ligne pour la base de donnee sur mon ordi        
%%    fprintf(fid_w,'INSERT INTO acorn_current_realtime (speed, direction, longitude, latitude, position_index, colour, site_code, time_start, poly_lonlat)\n');
%% ligne pour la table de la base de donne maplayers
%    fprintf(fid_w,'INSERT INTO acorn.realtime (speed, direction, longitude, latitude, position_index, colour, site_code, timecreated, poly_lonlat)\n');
%%
%    kk= int8(round(vrn1ge(3*(row-1)+1)));
%    if kk==0; kk=64; end
%    lineColor = CCge{64-kk+1};
%%
%    fprintf(fid_w,'VALUES (%s, %s, %s, %s, %s,\''%s\'',\''%s\'',\''%s\'' ,PolyFromText(\''POLYGON((',num2str(vr(row)/autoscale),num2str(final(row,6)),num2str(uui(3*(row-1)+1),'%11.7f'),num2str(vvi(3*(row-1)+1),'%11.7f'),num2str(final(row,7)),lineColor,site_code,timestampseb{7});
%    fprintf(fid_w, '%s %s , %s %s , ',num2str(uui3(5*(row-1)+3),'%11.7f'),num2str(vvi3(5*(row-1)+3),'%11.7f'),num2str(uui3(5*(row-1)+1),'%11.7f'),num2str(vvi3(5*(row-1)+1),'%11.7f'));
%    fprintf(fid_w, '%s %s , %s %s , ',num2str(uui2(4*(row-1)+1),'%11.7f'),num2str(vvi2(4*(row-1)+1),'%11.7f'),num2str(uui(3*(row-1)+2),'%11.7f'),num2str(vvi(3*(row-1)+2),'%11.7f'));
%    fprintf(fid_w, '%s %s , %s %s , ',num2str(uui2(4*(row-1)+3),'%11.7f'),num2str(vvi2(4*(row-1)+3),'%11.7f'),num2str(uui3(5*(row-1)+2),'%11.7f'),num2str(vvi3(5*(row-1)+2),'%11.7f'));
%    fprintf(fid_w, '%s %s , %s %s))\'',4326));\n',num2str(uui3(5*(row-1)+4),'%11.7f'),num2str(vvi3(5*(row-1)+4),'%11.7f'),num2str(uui3(5*(row-1)+3),'%11.7f'),num2str(vvi3(5*(row-1)+3),'%11.7f'));
%%
%    zz=zz+1;
%    end
%end
%fclose(fid_w)
