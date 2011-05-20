function [toto] = radar_CODAR_non_QC_to_ncWMS_main_UNIX_v1(site_code)
%
%site_code ='TURQ';
%example of function call
%acorn_listing_main_netcdf('TURQ')
%
%The text file 'TURQ_last_update.txt' contains the date of the last update one
%the first line of the file.
%
global logfile
logfile = '/var/lib/matlab_3/ACORN/CODAR/radar_CODAR_non_QC_processing_logfile.txt';
%see matlab code "acorn_summary_non_QC_CODAR.m" for any changes
global dfradialdata
dfradialdata = '/home/matlab_3/datafabric_root/opendap/ACORN/sea-state/';
global inputdir
inputdir = '/var/lib/matlab_3/ACORN/CODAR/nonQC_gridded/';
global outputdir
outputdir = '/var/lib/matlab_3/ACORN/CODAR/nonQC_gridded/output/';
global ncwmsdir
ncwmsdir = '/var/lib/netcdf_data/matlab_3/ncwms.emii.org.au_ncwms_data/CODAR/';
%
%USE of the site_code input to find the corresponding radar station
%
switch site_code
    case 'TURQ'
        station1 = 'CRVT';
        station2 = 'SBRD';
        filelastupdate = strcat(inputdir,'TURQ_last_update.txt');
    case 'BONC'
        station1 = 'BFCV';
        station2 = 'NOCR';
        filelastupdate = strcat(inputdir,'BONC_last_update.txt');
end
%OPEN the text file and read the first line
fid = fopen(filelastupdate,'r');
line = fgetl(fid);
data{1} = line;
fclose(fid);
%
year = data{1}(1:4);
month = data{1}(5:6);
day = data{1}(7:8);
hour = str2num(data{1}(10:11));
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Call the subfunction "radar_WERA_non_QC_subfunction1_UNIX_v1"
%the subfunction will return a list of NetCDF files available on the ARCS DAtafabric
%and ready for processing for a particular radar station
%the variables "final" is then created
test_subf1_1 = 0;
final = [];
%try
final = radar_CODAR_non_QC_to_ncWMS_subfunction1_UNIX_v1(year,month,day,hour,site_code);
test_subf1_1 = 1;
%catch
%        fid_w5 = fopen(logfile, 'a');
%        fprintf(fid_w5,'%s %s %s %s\r\n',datestr(clock),site_code,'Problem in subroutine1 to access files for this radar site',data{1});
%        fclose(fid_w5);
%end
%
%
if (test_subf1_1 == 1 && ~isempty(final))
%
    dimfile = length(final);
    k=1;
%
    for i = 1:dimfile
%for i = 1:1  
%       try
        toto = radar_CODAR_non_QC_to_ncWMS_subfunction2_UNIX_v1(final{i,1},site_code,k);
        toto
        k=k+1;
%The date included in the input file is then updated   
        fid_w4 = fopen(filelastupdate, 'w');
        fprintf(fid_w4, '%s\n',toto);
        fclose(fid_w4);
%       catch
%           fid_w5 = fopen(logfile, 'a');
%           fprintf(fid_w5,'%s %s %s\r\n',datestr(clock),'Problem in subroutine2 to process the following file',final{i,1});
%           fclose(fid_w5);
%       end
    end
%
else
    fid_w5 = fopen(logfile, 'a');
    fprintf(fid_w5,'%s %s %s %s\r\n',datestr(clock),site_code,'Problem : NO FILES TO PROCESS',data{1});
    fclose(fid_w5);
    quit
end
%
%quit
%
%
