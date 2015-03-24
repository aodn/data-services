function cleanNetCDF(missionPath)
%cleanNetCDF - removes files that don't match the QAQC
%
% Syntax:  cleanNetCDF
%
% Inputs:
%
%
% Outputs:badProfiles.csv
%
% Example:
%    cleanNetCDF
%
% Other files required: none
% Other m-files required:
% Subfunctions: none
% MAT-files required: none
%
% See also: aatams_sealtags_main
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 16-Aug-2012
dataWIP_Path         = getenv('data_wip_path');
[~,~,ncFileListALL]  = DIRR(strcat(missionPath,filesep,'*.nc'),'name');
ncFileListALL        = ncFileListALL';
nNCFILE              = length(ncFileListALL);

Filename_badLocation = fullfile(dataWIP_Path,getenv('log_bad_profiles_name'));

for iiFile = 1:nNCFILE

    if isempty(strfind(ncFileListALL{iiFile},'END'))
        ncid                    = netcdf.open(ncFileListALL{iiFile},'NC_NOWRITE');

        [filepath,filename,ext] = fileparts(ncFileListALL{iiFile});
        filename                = [filepath(length(strcat(dataWIP_Path,filesep,'NETCDF',filesep))+1:end) '/'  filename,ext];

        [allVarnames,~]         = listVarNC(ncid);
        LATITUDE                = getVarNC('LATITUDE',ncid);
        LONGITUDE               = getVarNC('LONGITUDE',ncid);
        TIME                    = getTimeDataNC(ncid);

        if (isnan(LATITUDE) | isnan(LONGITUDE))
            delete(ncFileListALL{iiFile})
            fid_corrupted = fopen(Filename_badLocation, 'a+');
            fprintf(fid_corrupted,'%s - NO LOCATION:    %s\n',datestr(now),filename);
            fclose(fid_corrupted);
        elseif  LATITUDE>0
            delete(ncFileListALL{iiFile})
            fid_corrupted = fopen(Filename_badLocation, 'a+');
            fprintf(fid_corrupted,'%s - NORTH HEMISHPERE:%s\n',datestr(now),filename);
            fclose(fid_corrupted);
        elseif isnan(TIME)
            delete(ncFileListALL{iiFile})
            fid_corrupted = fopen(Filename_badLocation, 'a+');
            fprintf(fid_corrupted,'%s - NO TIME:         %s\n',datestr(now),filename);
            fclose(fid_corrupted);
        end
        netcdf.close(ncid)
        clear filename
    end
end

fclose('all');

end

