function [toto] = acorn_listing_main_netcdf_UNIX(site_code,filename)
%
%example of function call
%acorn_listing_main_netcdf('SAG','SAG_SQL_last_update.txt')
%
%The text file 'SAG_SQL_last_update.txt' contains the date of the last update one
%the first line of the file.
%
%
switch site_code
    case 'GBR'
        station1 = 'TAN';
        station2 = 'LEI';
    case 'SAG'
        station1 = 'CWI';
        station2 = 'CSP';
    case 'PCY'
        station1 = 'GUI';
        station2 = 'FRE';
end
%
fid = fopen(filename,'r');
line = fgetl(fid);
data{1} = line;
fclose(fid);
%
year = data{1}(1:4);
month = data{1}(5:6);
day = data{1}(7:8);
hour = str2num(data{1}(10:11));
%
%Appel de la fonction qui renvoie le nombre de fichier pour chacune des
%deux stations
test_subf1_1 = 0;
try
final = acorn_listing_subfunction_1_netcdf_UNIX(year,month,day,hour,station1);
test_subf1_1 = 1;
catch
        fid_w5 = fopen('problem_log.txt', 'a');
        fprintf(fid_w5, 'Problem when accessing files from the following station %s and the date %s\n',station1,data{1});
        fclose(fid_w5);
end
%
test_subf1_2 = 0;
try
final2 = acorn_listing_subfunction_1_netcdf_UNIX(year,month,day,hour,station2);
test_subf1_2 = 1;
catch
        fid_w5 = fopen('/home/smancini/matlab_seb/ACORN/problem_log.txt', 'a');
        fprintf(fid_w5, 'Problem when accessing files from the following station %s and the date %s\n',station1,data{1});
        fclose(fid_w5);
end
%
if (test_subf1_1 == 1 && test_subf1_2 == 1)
%
dimfile = min(length(final),length(final2));
%
for i =1:dimfile
    datenumeric(i,1) = datenum(final{i,1}(15:29),'yyyymmddTHHMMSS');
    datenumeric(i,2) = datenum(final2{i,1}(15:29),'yyyymmddTHHMMSS');
end
%
%
j = datenumeric(1,1);
k=1;
while (j < datenumeric(end,1))
    verif(k,1) = j;
    verif(k,2) = j+1/24;
    j = j+1/24;
    k=k+1;
end
%
%
%dimhour = length(verif);
dimhour = size(verif,1);
%
k=1;
%
for i = 1:dimhour
%for i = 1:1  
    if (length(find(datenumeric >= verif(i,1) & datenumeric < verif(i,2))) == 12)
        verif(i,3) = 1;
        J = find(datenumeric >= verif(i,1) & datenumeric < verif(i,2));
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
        try
        toto = acorn_listing_subfunction_2_netcdf_UNIX(namefile,site_code,k);
        k=k+1;
%
        fid_w4 = fopen(filename, 'w');
        fprintf(fid_w4, '%s\n',toto);
        fclose(fid_w4);
        end
    end
end
%
else
    fid_w5 = fopen('/home/smancini/matlab_seb/ACORN/problem_log.txt', 'a');
    fprintf(fid_w5, 'A problem occur for the following file %s and the date %s\n',site_code,data{1});
    fclose(fid_w5);
    quit
end
%
%quit
%
%

