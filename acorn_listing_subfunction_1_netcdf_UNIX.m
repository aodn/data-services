function [final] = acorn_listing_subfunction_1_netcdf_UNIX(year,month,day,hour,station)
%
fileinput = strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',station,'/',year,'/',month,'/',day,'/*.nc');
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
fileinput = strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',station,'/',year,'/',month);
A = dir(fileinput);
dimday = length(A);
%
for k = 3:dimday
    if (str2num(A(k).name) > str2num(day))
        fileinput2 = strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',station,'/',year,'/',month,'/',A(k).name,'/*.nc');
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
            fileinput = strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',station,'/',year,'/',newmonth);
            A = dir(fileinput);
            dimday = length(A);
            for k = 3:dimday
                    fileinput2 = strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',station,'/',year,'/',newmonth,'/',A(k).name,'/*.nc');
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
            fileinput = strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',station,'/',year,'/',newmonth);
            A = dir(fileinput);
            dimday = length(A);
            for k = 3:dimday
                    fileinput2 = strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',station,'/',year,'/',newmonth,'/',A(k).name,'/*.nc');
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
            fileinput = strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',station,'/',year,'/',newmonth);
            A = dir(fileinput);
            dimday = length(A);
            for k = 3:dimday
                    fileinput2 = strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',station,'/',year,'/',newmonth,'/',A(k).name,'/*.nc');
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
            fileinput = strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',station,'/',year,'/',newmonth);
            A = dir(fileinput);
            dimday = length(A);
            for k = 3:dimday
                    fileinput2 = strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',station,'/',year,'/',newmonth,'/',A(k).name,'/*.nc');
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
            fileinput = strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',station,'/',year,'/',newmonth);
            A = dir(fileinput);
            dimday = length(A);
            for k = 3:dimday
                    fileinput2 = strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',station,'/',year,'/',newmonth,'/',A(k).name,'/*.nc');
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
            fileinput = strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',station,'/',year,'/',newmonth);
            A = dir(fileinput);
            dimday = length(A);
            for k = 3:dimday
                    fileinput2 = strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',station,'/',year,'/',newmonth,'/',A(k).name,'/*.nc');
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
            fileinput = strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',station,'/',year,'/',newmonth);
            A = dir(fileinput);
            dimday = length(A);
            for k = 3:dimday
                    fileinput2 = strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',station,'/',year,'/',newmonth,'/',A(k).name,'/*.nc');
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
            fileinput = strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',station,'/',newyear,'/',newmonth);
            A = dir(fileinput);
            dimday = length(A);
            for k = 3:dimday
                    fileinput2 = strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',station,'/',newyear,'/',newmonth,'/',A(k).name,'/*.nc');
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