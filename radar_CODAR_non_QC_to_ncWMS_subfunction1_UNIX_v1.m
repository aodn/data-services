function [final] = radar_CODAR_non_QC_to_ncWMS_subfunction1_UNIX_v1(year,month,day,hour,station)
%This subfunction will return a list of files available on the ARCS
%DATAFABRIC from the date specified and for a specific radar station
%The list of files is stored in the variable "final"
%Creation of the folder name where the search of netCDF files starts
global dfradialdata
%reminder dfradialdata ='/home/matlab_3/datafabric_root/opendap/ACORN/sea-state/';
%see matlab script 'radar_CODAR_non_QC_to_ncWMS_main_UNIX_v1.m' for any changes
fileinput = strcat(dfradialdata,station,'/',year,'/',month,'/',day,'/*.nc');
%
A = dir(fileinput);
%
dimfile = length(A);
%
j=1;
for i = 1:dimfile
    hourfile = str2num(A(i).name(24:25));
    if (hourfile>hour)
        final{j,1} = A(i).name;
        j=j+1;
    end
end
%
clear fileinput A dimfile i
%
if (hourfile > 22)
%
fileinput = strcat(dfradialdata,station,'/',year,'/',month);
A = dir(fileinput);
dimday = length(A);
%
for k = 3:dimday
    if (str2num(A(k).name) > str2num(day))
        fileinput2 = strcat(dfradialdata,station,'/',year,'/',month,'/',A(k).name,'/*.nc');
        B = dir(fileinput2);
        dimfile = length(B);
        for i =1:dimfile
            final{j,1} = B(i).name;
            j=j+1;
        end
    end
end
%
dayinmonth = str2num(A(dimday).name);
%
clear fileinput A dimday fileinput2 B dimfile
%
switch month
    case {'01','03','05','07','08'}
        if (dayinmonth > 30)
            newmonth = strcat('0',num2str(str2num(month)+1));
            fileinput = strcat(dfradialdata,station,'/',year,'/',newmonth);
            A = dir(fileinput);
            dimday = length(A);
            for k = 3:dimday
                    fileinput2 = strcat(dfradialdata,station,'/',year,'/',newmonth,'/',A(k).name,'/*.nc');
                    B = dir(fileinput2);
                    dimfile = length(B);
                    for i =1:dimfile
                        final{j,1} = B(i).name;
                        j=j+1;
                    end
            end
        end
    case {'04','06'}
        if (dayinmonth > 29)
            newmonth = strcat('0',num2str(str2num(month)+1));
            fileinput = strcat(dfradialdata,station,'/',year,'/',newmonth);
            A = dir(fileinput);
            dimday = length(A);
            for k = 3:dimday
                    fileinput2 = strcat(dfradialdata,station,'/',year,'/',newmonth,'/',A(k).name,'/*.nc');
                    B = dir(fileinput2);
                    dimfile = length(B);
                    for i =1:dimfile
                        final{j,1} = B(i).name;
                        j=j+1;
                    end
            end
        end
    case '02'
        bissextile = mod(str2num(year),4);
        if (bissextile > 0)
            if (dayinmonth > 27)
            newmonth = strcat('0',num2str(str2num(month)+1));
            fileinput = strcat(dfradialdata,station,'/',year,'/',newmonth);
            A = dir(fileinput);
            dimday = length(A);
            for k = 3:dimday
                    fileinput2 = strcat(dfradialdata,station,'/',year,'/',newmonth,'/',A(k).name,'/*.nc');
                    B = dir(fileinput2);
                    dimfile = length(B);
                    for i =1:dimfile
                        final{j,1} = B(i).name;
                        j=j+1;
                    end
            end 
            end
        else
            if (dayinmonth > 28)
            newmonth = strcat('0',num2str(str2num(month)+1));
            fileinput = strcat(dfradialdata,station,'/',year,'/',newmonth);
            A = dir(fileinput);
            dimday = length(A);
            for k = 3:dimday
                    fileinput2 = strcat(dfradialdata,station,'/',year,'/',newmonth,'/',A(k).name,'/*.nc');
                    B = dir(fileinput2);
                    dimfile = length(B);
                    for i =1:dimfile
                        final{j,1} = B(i).name;
                        j=j+1;
                    end
            end    
            end
        end
    case '09'
        if (dayinmonth > 29)
            newmonth = num2str(str2num(month)+1);
            fileinput = strcat(dfradialdata,station,'/',year,'/',newmonth);
            A = dir(fileinput);
            dimday = length(A);
            for k = 3:dimday
                    fileinput2 = strcat(dfradialdata,station,'/',year,'/',newmonth,'/',A(k).name,'/*.nc');
                    B = dir(fileinput2);
                    dimfile = length(B);
                    for i =1:dimfile
                        final{j,1} = B(i).name;
                        j=j+1;
                    end
            end
        end    
    case '10'
        if (dayinmonth > 30)
            newmonth = num2str(str2num(month)+1);
            fileinput = strcat(dfradialdata,station,'/',year,'/',newmonth);
            A = dir(fileinput);
            dimday = length(A);
            for k = 3:dimday
                    fileinput2 = strcat(dfradialdata,station,'/',year,'/',newmonth,'/',A(k).name,'/*.nc');
                    B = dir(fileinput2);
                    dimfile = length(B);
                    for i =1:dimfile
                        final{j,1} = B(i).name;
                        j=j+1;
                    end
            end
        end
    case '11'
        if (dayinmonth > 29)
            newmonth = num2str(str2num(month)+1);
            fileinput = strcat(dfradialdata,station,'/',year,'/',newmonth);
            A = dir(fileinput);
            dimday = length(A);
            for k = 3:dimday
                    fileinput2 = strcat(dfradialdata,station,'/',year,'/',newmonth,'/',A(k).name,'/*.nc');
                    B = dir(fileinput2);
                    dimfile = length(B);
                    for i =1:dimfile
                        final{j,1} = B(i).name;
                        j=j+1;
                    end
            end
        end
    case '12'
        if (dayinmonth > 30)
            newmonth = '01';
            newyear = num2str(str2num(year)+1);
            fileinput = strcat(dfradialdata,station,'/',newyear,'/',newmonth);
            A = dir(fileinput);
            dimday = length(A);
            for k = 3:dimday
                    fileinput2 = strcat(dfradialdata,station,'/',newyear,'/',newmonth,'/',A(k).name,'/*.nc');
                    B = dir(fileinput2);
                    dimfile = length(B);
                    for i =1:dimfile
                        final{j,1} = B(i).name;
                        j=j+1;
                    end
            end
        end
end
%
end
%
%
