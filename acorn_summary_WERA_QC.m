%Run the main program for each WERA radar site
%
%Creation of a log file
global logfile
logfile = '/var/lib/matlab_3/ACORN/WERA/radar_WERA_QC_processing_logfile.txt';
%
%Capricorn bunker Group (GBR) Radar Site
try
    radar_WERA_QC_main_UNIX('CBG')
catch
    fid_w = fopen(logfile,'a');
    fprintf(fid_w,'%s %s \r\n',datestr(clock),' PROBLEM to PROCESS DATA FOR THE RADAR SITE CBG ');
    fclose(fid_w);
end
%South Australia Gulf (SA) Radar Site
try
    radar_WERA_QC_main_UNIX('SAG')
catch
    fid_w = fopen(logfile,'a');
    fprintf(fid_w,'%s %s \r\n',datestr(clock),' PROBLEM to PROCESS DATA FOR THE RADAR SITE SAG ');
    fclose(fid_w);    
end
%Rottnest Shelf (WA) Radar Site
try
    radar_WERA_QC_main_UNIX('ROT')
catch
    fid_w = fopen(logfile,'a');
    fprintf(fid_w,'%s %s \r\n',datestr(clock),' PROBLEM to PROCESS DATA FOR THE RADAR SITE ROT ');
    fclose(fid_w);    
end
