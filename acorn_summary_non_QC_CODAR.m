%Run the main program for each CODAR radar site
%
%Creation of a log file
global logfile
logfile = '/var/lib/matlab_3/ACORN/CODAR/radar_CODAR_non_QC_processing_logfile.txt';
%Turquoise Coast
try
    radar_CODAR_non_QC_to_ncWMS_main_UNIX_v1('TURQ','TURQ_last_update.txt')
catch
    fid_w = fopen(logfile,'a');
    fprintf(fid_w,'%s %s \r\n',datestr(clock),' PROBLEM to PROCESS DATA FOR THE RADAR SITE TURQ ');
    fclose(fid_w);
end
%Bonney Coast to be added in the future
