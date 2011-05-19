function [toto] = radar_WERA_non_QC_main_UNIX_v1(site_code)
%example of function call
%acorn_listing_main_netcdf('SAG')
%
%The text file 'SAG_last_update.txt' contains the date of the last update one
%the first line of the file.
%
global logfile
logfile = '/var/lib/matlab_3/ACORN/WERA/radar_WERA_non_QC_processing_logfile.txt';
%see matlab code "acorn_summary_CBG_SAG_ROT.m" for any changes
global dfradialdata
dfradialdata = '/home/matlab_3/datafabric_root/opendap/ACORN/radial/';
global inputdir
inputdir = '/var/lib/matlab_3/ACORN/WERA/radial_nonQC/';
global outputdir
outputdir = '/var/lib/matlab_3/ACORN/WERA/radial_nonQC/output/';
global ncwmsdir
ncwmsdir = '/var/lib/netcdf_data/matlab_3/ncwms.emii.org.au_ncwms_data/WERA_non_QC/';
%
%USE of the site_code input to find the corresponding radar station
switch site_code
    case {'GBR','CBG'}
        station1 = 'TAN';
        station2 = 'LEI';
        filelastupdate = strcat(inputdir,'CBG_last_update.txt');
    case 'SAG'
        station1 = 'CWI';
        station2 = 'CSP';
        filelastupdate = strcat(inputdir,'SAG_last_update.txt');
    case {'PCY','ROT'}
        station1 = 'GUI';
        station2 = 'FRE';
        filelastupdate = strcat(inputdir,'ROT_last_update.txt');
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
%the variables "final" and "final2" are then created
%
%STATION 1
test_subf1_1 = 0;
%try
    final = radar_WERA_non_QC_subfunction1_UNIX_v1(year,month,day,hour,station1);
    test_subf1_1 = 1;
%catch
%        fid_w5 = fopen(logfile, 'a');
%        fprintf(fid_w5,'%s %s %s %s\r\n',datestr(clock),station1,'Problem in subroutine1 to access files for this station on the following date',data{1});
%        fclose(fid_w5);
%end
%STATION 2
test_subf1_2 = 0;
%try
    final2 = radar_WERA_non_QC_subfunction1_UNIX_v1(year,month,day,hour,station2);
    test_subf1_2 = 1;
%catch
%        fid_w5 = fopen(logfile, 'a');
%        fprintf(fid_w5,'%s %s %s %s\r\n',datestr(clock),station1,'Problem in subroutine1 to access files for this station on the following date',data{1});
%        fclose(fid_w5);
%end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%TEST to check if data is available for the two radar stations
if (test_subf1_1 == 1 && test_subf1_2 == 1)
%
    dimfile = min(length(final),length(final2));
%Store the date in a numeric format of all the data files available for
%each station
    for i =1:dimfile
        datenumeric(i,1) = datenum(final{i,1}(15:29),'yyyymmddTHHMMSS');
        datenumeric(i,2) = datenum(final2{i,1}(15:29),'yyyymmddTHHMMSS');
    end
%Creation of another variable "verif" to store the start time and end time
%from the first file available to the last.
    j = datenumeric(1,1);
    k=1;
    while (j < datenumeric(end,1))
        verif(k,1) = j;
        verif(k,2) = j+1/24;
        j = j+1/24;
        k=k+1;
    end
%Dimension of the variable "verif"
%dimhour = length(verif);
    dimhour = size(verif,1);
%
    k=1;
%
    for i = 1:dimhour
%for i = 1:1 
%Each radar stations is transmitteing data every 10 minutes.
%over an hour, 6 data files are normally created for each radar stations
%I am checking if the number of data files from the radar site (2 stations)
%is equal to 12 over an hour. 
        if (length(find(datenumeric >= verif(i,1) & datenumeric < verif(i,2))) == 12)
            verif(i,3) = 1;
            J = find(datenumeric >= verif(i,1) & datenumeric < verif(i,2));
%Creation of a new variable "namefile" to store all the NetCDF filename (12 in total)        
            namefile{1}  = final{J(1),1};
            namefile{2}  = final2{J(7)-dimfile,1};
            namefile{3}  = final{J(2),1};
            namefile{4}  = final2{J(8)-dimfile,1};
            namefile{5}  = final{J(3),1};
            namefile{6}  = final2{J(9)-dimfile,1};
            namefile{7}  = final{J(4),1};
            namefile{8}  = final2{J(10)-dimfile,1};
            namefile{9}  = final{J(5),1};
            namefile{10} = final2{J(11)-dimfile,1};
            namefile{11} = final{J(6),1};
            namefile{12} = final2{J(12)-dimfile,1};        
%         fid_w4 = fopen('data.txt', 'w');
%         fprintf(fid_w4, '%s\n%s\n',final{J(1),1},final2{J(7)-dimfile,1});
%         fprintf(fid_w4, '%s\n%s\n',final{J(2),1},final2{J(8)-dimfile,1});
%         fprintf(fid_w4, '%s\n%s\n',final{J(3),1},final2{J(9)-dimfile,1});
%         fprintf(fid_w4, '%s\r%s\r',final{J(4),1},final2{J(10)-dimfile,1});
%         fprintf(fid_w4, '%s\r%s\r',final{J(5),1},final2{J(11)-dimfile,1});
%         fprintf(fid_w4, '%s\r%s\r',final{J(6),1},final2{J(12)-dimfile,1});
%         fclose(fid_w4);
%Call the subfunction "radar_WERA_non_QC_subfunction2_UNIX_v1"
%the subfunction will open the NetCDF files and process the data in order
%to create a new NetCDF file (1 hour averaged product)
%            try
                toto = radar_WERA_non_QC_subfunction2_UNIX_v1(namefile,site_code,k);
                toto
                k=k+1;
%The date included in the input file is then updated                  
                fid_w4 = fopen(filelastupdate, 'w');
                fprintf(fid_w4, '%s\n',toto);
                fclose(fid_w4);
%            catch
%                fid_w5 = fopen(logfile, 'a');
%                fprintf(fid_w5,'%s %s %s\r\n',datestr(clock),'Problem in subroutine2 to process the following file',namefile{1});
%                fclose(fid_w5);
%            end
        end
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

