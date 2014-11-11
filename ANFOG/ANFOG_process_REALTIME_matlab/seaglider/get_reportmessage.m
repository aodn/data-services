function message = get_reportmessage(index)
%output report message according to index
switch index
    case 1
        message = ' has been processed for the first time';
    case 2
        message = ' has been updated';
    case 3
        message = ' has NO UPDATE';
    case 4
        message = ' PROBLEM to copy locally the comm.log file for the following deployment ';
    case 5
        message = ' PROBLEM during the processing of the following deployment ';
    case 6
        message = ' No Deployment to process';
    case 7
        message = ' The Deployment ';
    case 8
        message = ' PROBLEM to create a folder on the DataFabric for the following deployment ';
    case 9
        message = ' PROBLEM to copy locally NETCDF FILES for the following deployment '; 
    case 10 
        message = ' PROBLEM to create the plots for the following deployment ';
    case 11 
        message = ' PROBLEM in the GTS function for this deployment ';
end