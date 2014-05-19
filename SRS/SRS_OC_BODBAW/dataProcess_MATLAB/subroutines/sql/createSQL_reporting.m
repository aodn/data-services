function createSQL_reporting(dataProcessedLocation,timeStaging)

timeOpendapPortal = datestr(now+1,'yyyy-mm-dd');

Filename_DB=fullfile(dataProcessedLocation(1:end-length('/NetCDF')),filesep,'BioOptical_ReportingDB.sql');
fid_DB = fopen(Filename_DB, 'a+');

FacilitySuffixe=readConfig('netcdf.facility_suffixe', 'config.txt','=');
DataType=readConfig('netcdf.data_type', 'config.txt','=');   %<Data-Code> IMOS filenaming convention

cruiseList = dir([dataProcessedLocation filesep '*cruise*']);

for iiCruise = 1:length(cruiseList)
    data_type = dir([dataProcessedLocation filesep cruiseList(iiCruise).name  ]);
    
    for iiDataType = 3 :length(data_type)
        ncFileList = dir([dataProcessedLocation filesep cruiseList(iiCruise).name filesep data_type(iiDataType).name filesep '*.nc']);
        
        dataTypeCruise = data_type(iiDataType).name;
        % we are looking for each cruise for the min date coverage start
        % and max date coverage end
        for iiNC = 1:length(ncFileList)
            filepath = [dataProcessedLocation filesep cruiseList(iiCruise).name filesep data_type(iiDataType).name filesep ncFileList(iiNC).name];
            srs_DATA = ncParse(filepath) ;
            time_coverage_start(iiNC) = datenum(srs_DATA.metadata.time_coverage_start,'yyyy-mm-ddTHH:MM:SS');
            time_coverage_end(iiNC) = datenum(srs_DATA.metadata.time_coverage_end,'yyyy-mm-ddTHH:MM:SS');
            
        end
        deploymentStart = min (time_coverage_start);
        deploymentEnd = max (time_coverage_end);
        cruiseID = srs_DATA.metadata.cruise_id;
        
%         fprintf(fid_DB,'BEGIN;\n');
%         fprintf(fid_DB,'INSERT INTO report.srs_bio_optical_db_manual (pkid,cruise_id,data_type,deployment_start,deployment_end,data_on_staging,data_on_opendap,data_on_portal)\n');
%         fprintf(fid_DB,'VALUES ( nextval(''report.hibernate_sequence''),''%s\'',''%s\'' , ''%s\'' , ''%s\'' , ''%s\'',''%s\'' , ''%s\'' ); \n',...
%             cruiseID,dataTypeCruise,datestr(deploymentStart,'yyyy-mm-dd'),datestr(deploymentEnd,'yyyy-mm-dd'),...
%             timeStaging, timeOpendapPortal, timeOpendapPortal);
%         fprintf(fid_DB,'COMMIT;\n');

        fprintf(fid_DB,'BEGIN;\n');
        fprintf(fid_DB,'INSERT INTO report.srs_bio_optical_db_manual (pkid,cruise_id,data_type,deployment_start,deployment_end,data_on_staging,data_on_opendap,data_on_portal)\n');
        fprintf(fid_DB,'SELECT  nextval(''report.hibernate_sequence''),''%s\'',''%s\'' , ''%s\'' , ''%s\'' , ''%s\'',''%s\'' , ''%s\''  WHERE NOT EXISTS (SELECT pkid FROM report.srs_bio_optical_db_manual  WHERE data_type = ''%s\'' AND cruise_id = ''%s\'' ); \n',...
            cruiseID,dataTypeCruise,datestr(deploymentStart,'yyyy-mm-dd'),datestr(deploymentEnd,'yyyy-mm-dd'),...
            timeStaging, timeOpendapPortal, timeOpendapPortal,dataTypeCruise,cruiseID);
        fprintf(fid_DB,'COMMIT;\n');
        
    end
    
end

fclose(fid_DB);
end
