function bool = isLatLonBad (filename)
%percentageFactor=0.3;
%nTimesBigger=6;

nc = netcdf.open(filename,'NC_WRITE');
%% list all the Variables
[VARNAME,~]=listVarNC(nc);
lat=getVarNC('latitude',VARNAME,nc);lon=getVarNC('longitude',VARNAME,nc);
if  sum(lat>0)~=0 || sum(lon>180)~=0 %boundaries
    bool=1;
else
%    ( ( max(diff(lon)) > (abs(mean(diff(lon)))+ var(diff(lon)) ) + (abs(mean(diff(lon)))+ var(diff(lon)) ) *percentageFactor )==1 && ...
%            (max(lon) > (median(lon)+nTimesBigger*var(lon)) |  min(lon) < (median(lon)-nTimesBigger*var(lon)))==1) ...
%            | ...
%            ( (max(diff(lat)) > (abs(mean(diff(lat)))+ var(diff(lat)) ) + (abs(mean(diff(lat)))+ var(diff(lat)) ) *percentageFactor )==1 && ...
%            (max(lat) > (median(lat)+nTimesBigger*var(lat)) |  min(lat) < (median(lat)-nTimesBigger*var(lat)))==1 )
%  %basic QAQC  . check values arren't extreme
%        bool=1;
%    else
        bool=0;
%    end
end
netcdf.close(nc);
end

