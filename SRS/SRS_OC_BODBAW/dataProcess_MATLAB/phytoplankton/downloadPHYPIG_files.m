%% copy all the XLS PHYPIG  files from the data fabric

DataFileFolder='/home/lbesnard/IMOS/BioOpticalData/MatlabScript/ToConvert/PhytoPlankton/';
DataFabricFolder='/media/webdav_arcs/IMOS/public/ANMN/NRS/';

ListStation=dir(DataFabricFolder);


for ii=1:length(ListStation) 
    if ListStation(ii).isdir==1
    SourceFolder=strcat(DataFabricFolder,ListStation(ii).name,'/BIOGEOCHEM/Phytoplankton/');
    DestinationFolder=strcat(DataFileFolder,ListStation(ii).name,'/BIOGEOCHEM/Phytoplankton/');

      if exist(SourceFolder,'dir') ==7
          XLSfile=dir(strcat(SourceFolder,'*FV01_PHYPIG*.xls'));
          for jj=1:length(XLSfile)
              if ~exist(DestinationFolder,'dir')
                mkdir(DestinationFolder)
              end
          copyfile(strcat(SourceFolder,XLSfile(jj).name),DestinationFolder)
          end
      end
    end
end