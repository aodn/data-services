function [track_csv] = readCSV_track (Campaign,Dive,header_data)

releasedCampaignPath = readConfig('releasedCampaign.path', 'config.txt','=');

divePath             = strcat(releasedCampaignPath,filesep,Campaign,filesep,Dive);
Track_dir            = dir([divePath filesep 'track*']);
trackPath            = [divePath filesep Track_dir.name];

%%  get the image filename and remove the extention as the CSV doesn't contain the extention
Image_name           = strtok({header_data.image}','.');
Image_name           = Image_name';
nrows                = length(header_data);


if ~size(Track_dir,1)
    fprintf('%s - WARNING: Missing folder "track_files"  for %s\n',datestr(now), [Campaign '-' Dive]);
    track_csv = struct;
    return
else
    File_track_csv           = dir([trackPath filesep '*.csv']);
    Filename_CSV_Coordinates = strcat(releasedCampaignPath,filesep,Campaign,filesep,Dive,filesep,Track_dir.name,filesep,File_track_csv.name);       %CSV file in the track dire
    
    %% Import depth,altitude... and time from LatLon CSV file
    fid2                     = fopen(Filename_CSV_Coordinates,'r');
    try
        [~, C_data2] = csvload(Filename_CSV_Coordinates);
    catch
        fprintf('%s - ERROR: %s is corrupted\n',datestr(now),[Track_dir.name filesep File_track_csv.name]);
        track_csv = struct;
        return
    end
    
    fclose(fid2);
    
    %% get file name from file fid2 , to get the filename and remove the ext
    Filename_latlon_pre = {C_data2{1,2}{:,1}}';%(1,2:end-1) remove the "
    [Filename_latlon ~] = strtok(Filename_latlon_pre,'.');
    
    
    
    %Load of the spreadsheet
    DATA_latlon     = C_data2{1,1};
    Year_latlon     = DATA_latlon(:,1);
    Month_latlon    = DATA_latlon(:,2);
    Day_latlon      = DATA_latlon(:,3);
    Hour_latlon     = DATA_latlon(:,4);
    Minute_latlon   = DATA_latlon(:,5);
    Sec_latlon      = DATA_latlon(:,6);
    Depth_latlon    = DATA_latlon(:,9);
    Altitude_latlon = DATA_latlon(:,15);
    
    %cluster tag - Only available in new versions of csv file
    if size (C_data2,2 )== 3
        Cluster_Tag =C_data2{:,3};
    elseif size (C_data2,2) == 2
        % Image labels denote the class or cluster assigned to an image.  A zero (0) indicates
        % no label data was available for that image.
        % so if we have an old version of a csv file where cluster tag does not
        % exist, we replace the values by 0
        Cluster_Tag =zeros(nrows,1);
    end
   
    %% Find image name into both CSV to find an equivalent index
    index_equivalent2 =int16(find(ismember( Filename_latlon(:), Image_name(:))==1)');
    
    track_csv = struct;
    
    track_csv.Year        = Year_latlon(index_equivalent2);
    track_csv.Month       = Month_latlon(index_equivalent2);
    track_csv.Day         = Day_latlon(index_equivalent2);
    track_csv.Hour        = Hour_latlon(index_equivalent2);
    track_csv.Minute      = Minute_latlon(index_equivalent2);
    track_csv.Sec         = Sec_latlon(index_equivalent2);
    track_csv.Depth       = Depth_latlon(index_equivalent2);
    track_csv.Altitude    = Altitude_latlon(index_equivalent2);
    track_csv.Bathy       = track_csv.Altitude+track_csv.Depth;%in (m)
    track_csv.Cluster_Tag = Cluster_Tag(index_equivalent2);
    

end