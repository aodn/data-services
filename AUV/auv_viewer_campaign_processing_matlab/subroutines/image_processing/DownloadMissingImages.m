function DownloadMissingImages(Dive,AUV_Folder,Save_Folder,Campaign) 


warning('off','MATLAB:dispatcher:InexactCaseMatch')

cd (strcat(AUV_Folder,filesep,Campaign,filesep,Dive))
Hydro_dir=dir('h*');
Track_dir=dir('track*');
TIFF_dir=dir('i2*gtif');

cd(Hydro_dir.name);
Files_Hydro_dir=dir('*.nc'); % structure 1 and 2 matche the files
cd (strcat(AUV_Folder,filesep,Campaign,filesep,Dive))

cd(Track_dir.name);
File_track_csv=dir('*.csv');
% File_track_kml=dir('*.kml');
cd (strcat(AUV_Folder,filesep,Campaign,filesep,Dive))


Filename_CSV_Coordinates    =strcat(AUV_Folder,filesep,Campaign,filesep,Dive,filesep,Track_dir.name,filesep,File_track_csv.name);       %CSV file in the track dire


cd(TIFF_dir.name);

list_images=dir('*.tif');
header_data=struct;
k=0;
for j=1:length(list_images)
    try   %try catch if the image is corrupted
    k=k+1;  %the header_data works with the k index since it avoids to have an empty header_data index to occur if the image is corrupted
    header_data(k,1).image=list_images(j).name;
    catch %if the image is corrupted, it is listed  
    end
end

     
    
Image_name=[];
%to get the image filename and remove the extention as the CSV doesn't contain
%the extention
try
Image_name=strtok({header_data.image}','.');
clear k
Image_name=Image_name';
nrows=length(header_data);
catch Er
    Er=0;
end

fid2 = fopen(Filename_CSV_Coordinates,'r');
C_text2 = textscan(fid2, '%s', 17, 'delimiter', ',');                       %C_text{1}{2} C_text{1}{1} to get values;
C_data2 = textscan(fid2, '%n %n %n %n %n %f %f %f %f %f %f %f %f %f %f %s %s ','CollectOutput', 1,'treatAsEmpty', {'NA', 'na'}, 'Delimiter', ',');
fclose(fid2);

Filename_latlon_pre=[];                                                     %get file name from file fid2 , to get the filename and remove the ext
Filename_latlon_pre={C_data2{1,2}{:,1}}';%(1,2:end-1) remove the "
[Filename_latlon extention] = strtok(Filename_latlon_pre,'.');
clear extention Filename_latlon_pre;



index_equivalent2=[];
if ~isempty(Image_name)
%%%%%%%%%%% Find missing image names into CSV to find an equivalent index%%%%%%%
index_equivalent2=int16(find(ismember( Filename_latlon(:), Image_name(:))==0)');
else
    index_equivalent2=int16(1:length(Filename_latlon));
end

    

for t=1:length(index_equivalent2)
    mkdir(strcat(Save_Folder,filesep,Campaign,filesep,Dive,filesep,TIFF_dir.name))
    % HTTPS download
    %      URL=strcat('''https://df.arcs.org.au/ARCS/projects/IMOS/public/AUV/',Campaign,filesep,Dive,filesep,TIFF_dir.name,filesep,Filename_latlon{index_equivalent2(t)},'.tif''')
    %      [f, status]=urlwrite(URL, strcat(Save_Folder,filesep,Campaign,filesep,Dive,filesep,TIFF_dir.name,filesep,Filename_latlon{t},'.tif') )
    %     %     if status == 0
    % WEBDAV download
    %         URL=strcat(ARCS_Folder,filesep,Campaign,filesep,Dive,filesep,TIFF_dir.name,filesep,Filename_latlon{t},'.tif')
    %         [status,message,messageId]=copyfile(URL, strcat(Save_Folder,filesep,Campaign,filesep,Dive,filesep,TIFF_dir.name,filesep,Filename_latlon{index_equivalent2(t)},'.tif') )
    %     end
    
    
    URL=strcat('https://df.arcs.org.au/ARCS/projects/IMOS/public/AUV/',Campaign,filesep,Dive,filesep,TIFF_dir.name,filesep,Filename_latlon{index_equivalent2(t)},'.tif')
    systemCmd = sprintf('wget %s -P%s --no-check-certificate',URL,strcat(Save_Folder,filesep,Campaign,filesep,Dive,filesep,TIFF_dir.name))
    [status, result] =system(systemCmd,'-echo') ;
%         [status, result] =system(systemCmd) 

    
    if status ~= 0
        Filename_FilesNotDownloaded=strcat(Save_Folder,filesep,'ReadME_FilesNotDownloaded.txt');
        fid_FilesNotDownloaded = fopen(Filename_FilesNotDownloaded, 'a+');
        fprintf(fid_FilesNotDownloaded,'%s \n', strcat('ARCS/projects/IMOS/public/AUV/',Campaign,filesep,Dive,filesep,TIFF_dir.name,filesep,Filename_latlon{index_equivalent2(t)},'.tif'));
        fclose(fid_FilesNotDownloaded);
    end
   
end

end

