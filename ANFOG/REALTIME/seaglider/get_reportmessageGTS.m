function message = get_reportmessageGTS(index)


switch index
    case 1
        message = ' TESAC messages have been created for the NetCDF file ';
    case 2
        message = ' Problem when creating a TESAC message for the following NetCDF file ';
    case 3
        message = ' TESAC messages have been created for the NetCDF file ';
    case 4
        message = ' Problem when creating a TESAC message for the following NetCDF file ';
    case 5
        message = ' Problem to COPY THE FOLLOWING FILE TO the BOM ftp site ';
    case 6
        message = ' Problem to access the BOM ftp site ';
    case 7
        message = ' Problem to COPY THE FOLLOWING FILE TO the NOAA ftp site ';
    case 8
        message = ' Problem to access the NOAA ftp site ';
    case 9
        message = ' Data included in this NetCDF file can not be transmitted to the GTS';
end