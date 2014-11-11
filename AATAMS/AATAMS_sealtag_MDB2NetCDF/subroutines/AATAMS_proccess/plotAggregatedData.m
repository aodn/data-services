function plotAggregatedData

global DATA_FOLDER;
dirprocessed = strcat(DATA_FOLDER,'/NETCDF/');
listCruise = dir(strcat(dirprocessed,'2*'));
%
nCruise=length(listCruise); % try cql filter device_wmo_ref= 'Q9900449' and iiCruise=11
for iiCruise =1:nCruise
    listfolder = dir(strcat(dirprocessed,listCruise(iiCruise).name));
    
    nbprocessedfolder = length(listfolder);
    
    for i =1:nbprocessedfolder
        if (listfolder(i).isdir)
                
                listAggregatedProfile= dir(strcat(dirprocessed,listCruise(iiCruise).name,filesep,listfolder(i).name,filesep,'*.nc'));
                
                if ~isempty(listAggregatedProfile)
                    filename_path=strcat(dirprocessed,listCruise(iiCruise).name,filesep,listfolder(i).name,filesep,listAggregatedProfile.name);
                    nc=netcdf.open(filename_path,'NC_NOCLOBBER');
                    [allVarnames,allVaratts]=listVarNC(nc);
                    LATITUDE=getVarNC('LATITUDE',allVarnames,nc);
                    LONGITUDE=getVarNC('LONGITUDE',allVarnames,nc);
                    
                    netcdf.close(nc)
                    
                    f=figure;
                    if sum(LONGITUDE<0)==0
                    plot(LONGITUDE,LATITUDE)
                    title(strrep([listCruise(iiCruise).name filesep listfolder(i).name '.Close figure to see next'],'_',' '))
                    else
                        LONGITUDE_BIS=LONGITUDE;
                        LONGITUDE_BIS(LONGITUDE_BIS<0)=LONGITUDE_BIS(LONGITUDE_BIS<0)+360;
                        plot(LONGITUDE_BIS,LATITUDE)
                        title(strrep(['CORRETECTED ' listCruise(iiCruise).name filesep listfolder(i).name '.Close figure to see next'],'_',' '))

                    end
                    waitfor(f)
                end
                
        end
    end
end
