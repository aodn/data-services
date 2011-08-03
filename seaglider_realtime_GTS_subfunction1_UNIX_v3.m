function [nCycleToProcess, okForGTS] = seaglider_realtime_GTS_subfunction1_UNIX_v3(deployment, filename)
%
%
global outputdir
%outputdir = '/var/lib/matlab_3/ANFOG/realtime/seaglider/output';
%OUTPUT: LOG FILE
logfile = strcat(outputdir,'/','seaglider_realtime_logfile_TEST.txt');
%
TESACoutput = strcat(outputdir, '/GTS/', deployment, '/TESACmessages/');
if (~exist(TESACoutput,'dir'))
    mkdir( TESACoutput );
end
if (~exist( strcat(TESACoutput, 'archive/'),'dir'))
    mkdir( strcat(TESACoutput, 'archive/') );
end
%
netcdfToProcess = strcat(outputdir, '/plotting/', deployment, '/', filename);
%
nc = netcdf.open(netcdfToProcess, 'NC_NOWRITE');
%
    temp_varid = netcdf.inqVarID(nc,'TIME');
    temp = netcdf.getVar(nc,temp_varid);
    TIME = temp(:);
%    
    temp_varid = netcdf.inqVarID(nc,'LATITUDE');
    temp = netcdf.getVar(nc,temp_varid);
    LATITUDE = temp(:);
%    
    temp_varid = netcdf.inqVarID(nc,'LONGITUDE');
    temp = netcdf.getVar(nc,temp_varid);
    LONGITUDE = temp(:);
%    
    temp_varid = netcdf.inqVarID(nc,'DEPTH');
    temp = netcdf.getVar(nc,temp_varid);
    DEPTH = temp(:);
%    
    temp_varid = netcdf.inqVarID(nc,'TEMP');
    temp = netcdf.getVar(nc,temp_varid);
    TEMP = temp(:);    
%    
    temp_varid = netcdf.inqVarID(nc,'PSAL');
    temp = netcdf.getVar(nc,temp_varid);
    PSAL = temp(:); 
%    
    temp_varid = netcdf.inqVarID(nc,'DEPTH_quality_control');
    temp = netcdf.getVar(nc,temp_varid);
    DEPTH_quality_control = temp(:);
%    
    temp_varid = netcdf.inqVarID(nc,'TEMP_quality_control');
    temp = netcdf.getVar(nc,temp_varid);
    TEMP_quality_control = temp(:);    
%    
    temp_varid = netcdf.inqVarID(nc,'PSAL_quality_control');
    temp = netcdf.getVar(nc,temp_varid);
    PSAL_quality_control = temp(:);     
%
    clear temp
netcdf.close(nc);    
%
%Number of data points included in the File
%
nValues = size(DEPTH,1);
%
%Use of the function 'diff' to calculate the differences between adjacent
%elements of DEPTH
%The result is a vector with a size equal to (nValues-1)
temp = (DEPTH(:) == 99999 );
if (~isempty(temp))
   DEPTH(temp) = NaN;
end
clear temp
diffDepth = diff(DEPTH);
%
%Search for positive values of the difference of depth
%The values is equal to 1 if the difference in depth is positive
%and is equal to 0 if the difference in depth is negative
positives = diffDepth >= 0;
%
%Calculate the difference between adjacent elements of positives
%The results is a vector with a size equal to (nValues - 2)
diffProfile = diff(positives);
%
%Index where the glider is changing direction (going upward or downward)
%Find the values equal to 1 or -1 in the vector diffProfile
turnPoint = find(diffProfile == 1 | diffProfile == -1) + 1;
%nTurnPoint represents the number of times where the glider is changing
%direction
if (~isempty(turnPoint))
    nTurnPoint = size(turnPoint, 1);
end
%
%Creation of a matrix 'indexCycle' to store the index of the start and end
%of each profile performed by the glider.
%Each row represent one profile
%First Column: index of the start of the profile
%Second column: index of the end of the profile
%Third colum: number of data points minus 1 for each profile
if nTurnPoint == 0 %one profile
    indexCycle(1, 1)   = 1;
    indexCycle(1, 2)   = nValues;
    indexCycle(1, 3)   = indexCycle(1, 2) - indexCycle(1, 1); 
elseif nTurnPoint == 1 %two profiles (one ascent and one descent)
    indexCycle(1, 1)   = 1;
    indexCycle(1, 2)   = turnPoint(1) - 1;
    indexCycle(1, 3)   = indexCycle(1, 2) - indexCycle(1, 1);
    indexCycle(2, 1)   = turnPoint(1) + 1;
    indexCycle(2, 2)   = nValues;
    indexCycle(2, 3)   = indexCycle(2, 2) - indexCycle(2, 1);
else % multiple profiles (multiple ascents and descents)
    indexCycle(1, 1)                = 1;
    indexCycle(1, 2)                = turnPoint(1) - 1;
    indexCycle(1, 3)                = indexCycle(1, 2) - indexCycle(1, 1);
    indexCycle(nTurnPoint + 1, 1)   = turnPoint(nTurnPoint) + 1;
    indexCycle(nTurnPoint + 1, 2)   = nValues; 
    indexCycle(nTurnPoint + 1, 3)   = indexCycle(nTurnPoint + 1, 2) - indexCycle(nTurnPoint + 1, 1);
    for j = 1:nTurnPoint-1
        indexCycle(j+1, 1)    = turnPoint(j) + 1;
        indexCycle(j+1, 2)    = turnPoint(j+1) - 1;
        indexCycle(j+1, 3)    = indexCycle(j+1, 2) - indexCycle(j+1, 1);
    end
end
%
%Numbers of ascent and descent
nCycle = size(indexCycle, 1);
%
%Index of Cycles good for processing.
%Sometimes the glider is doing some up and down near the surface.
%The third colum of the vector indexCycle is a good indicator of which
%profiles are good for processing
%If the number of data for a profile is less than 10, I do not process it
cycleToProcess  = find(indexCycle(:, 3) > 10);
%
%
if ( ~isempty(cycleToProcess) )
  nCycleToProcess = size(cycleToProcess, 1);
%
  for i = 1:nCycleToProcess
%  for i =1:1  
%Number of data points for each profile      
    nProfileValues = ( indexCycle(cycleToProcess(i),2) - indexCycle(cycleToProcess(i),1) ) + 1;
%Creation of the matrix 'data' to store the values of each variable for the 
%corresponding profile    
    data       = NaN(nProfileValues, 9);
%    
    data(:, 1) = TIME( indexCycle(cycleToProcess(i), 1) : indexCycle(cycleToProcess(i), 2) );
    data(:, 2) = LATITUDE( indexCycle(cycleToProcess(i),1) : indexCycle(cycleToProcess(i), 2) );
    data(:, 3) = LONGITUDE( indexCycle(cycleToProcess(i),1) : indexCycle(cycleToProcess(i), 2) );
    data(:, 4) = DEPTH( indexCycle(cycleToProcess(i), 1): indexCycle(cycleToProcess(i), 2) );
    data(:, 5) = DEPTH_quality_control( indexCycle(cycleToProcess(i), 1) : indexCycle(cycleToProcess(i), 2) );
    data(:, 6) = TEMP( indexCycle(cycleToProcess(i), 1) : indexCycle(cycleToProcess(i), 2) );
    data(:, 7) = TEMP_quality_control( indexCycle(cycleToProcess(i), 1) : indexCycle(cycleToProcess(i), 2) );
    data(:, 8) = PSAL( indexCycle(cycleToProcess(i), 1) : indexCycle(cycleToProcess(i), 2) );
    data(:, 9) = PSAL_quality_control( indexCycle(cycleToProcess(i), 1) : indexCycle(cycleToProcess(i), 2) );    
%Replace FillValue by NaN
    temp = (data(:, 4) == 99999 | data(:, 6) == 99999 | data(:, 8) == 99999);
    data(temp, :) = NaN;
    clear temp
%Use the quality control information to only use good data
    qcTest = (data(:, 5) ~=1 | data(:, 7) ~=1 | data(:, 9) ~=1);
    data(qcTest, :) = NaN;
    clear qcTest
%
%Keep only lines with good data
    Flog  = (~isnan(data(:,1)));
    nData = sum(Flog);
%Creation of the matrix final    
    final = NaN(nData, 6);
    final(:, 1)  = data(Flog, 1); %TIME
    final(:, 2)  = data(Flog, 2); %LATITUDE
    final(:, 3)  = data(Flog, 3); %LONGITUDE
    final(:, 4)  = data(Flog, 4); %DEPTH
    final(:, 5)  = data(Flog, 6); %TEMPERATURE
    final(:, 6)  = data(Flog, 8); %SALINITY  
    clear Flog nData
%
%Test if the profile is acending or descending
%If the profile is acending then we transpose the vector
%
    profileType = (final(2, 4) - final(1, 4));
    if (profileType < 0) %ascending profile
        final = final(end:-1:1, :);
    end
    clear profileType
%
%Average of the depth difference 
%I will only include data every 2 meters or more in the TESAC Message
    diffDepthProfile = diff( final(:, 4));
    indexRedundant = find(diffDepthProfile <= 0);
    if ~isempty(indexRedundant)
      final(indexRedundant+1, :) = [];
    end
    clear indexRedundant 
    spaceMeter = max(2, round( mean(abs(diffDepthProfile))));
%Number of data points to include in the TESAC message
    nDataInterp = floor((floor(final(end,4)) - ceil(final(1,4)))/spaceMeter) + 1;
% Check if the number of the data is less than 740
% in order to have a message with a size < 15 Kb (requirement of the GTS)
% if it is over 740 then I keep the same amount of data until 300 meters
% and i subset below that depth until the bottom
    mediumDepth = 300;
    nDataInterp1 = 500;
    nDataInterp2 = 500;
    ll = 1;
    if (nDataInterp < 740)    
        finalInterp = NaN(nDataInterp, 4);
        finalInterp(:, 1) = ceil(final(1,4)) : spaceMeter : floor(final(end,4));
    else
        while (nDataInterp1+nDataInterp2) > 740
          finalInterp = NaN( nDataInterp1 + nDataInterp2, 4);    
%Data from the surface to the mediumDepth          
          nDataInterp1 = floor((mediumDepth - ceil(final(1,4)))/spaceMeter) + 1;
          finalInterp(1:nDataInterp1, 1) = ceil(final(1, 4)) : spaceMeter : mediumDepth;
%Data from the mediumDepth to the bottom          
          nDataInterp2 = floor((floor(final(end,4)) - (finalInterp(nDataInterp1,1) + spaceMeter + ll)) / (spaceMeter+ll)) + 1;
          finalInterp(nDataInterp1+1 : nDataInterp1+nDataInterp2, 1) = finalInterp(nDataInterp1, 1) + spaceMeter+ll : spaceMeter+ll : floor(final(end,4));
          ll = ll+1;
        end
    end
    clear nDataInterp1 nDataInterp2 ll
% Use the function 'interp1' to find the nearest values for each variable
% (Depth, Temperature and Salinity) for the selected depth.
    finalInterp(:,2) = interp1(final(:, 4) , final(:, 5) , finalInterp(:, 1), 'nearest');
    finalInterp(:,3) = interp1(final(:, 4) , final(:, 6) , finalInterp(:, 1), 'nearest');
    finalInterp(:,4) = interp1(final(:, 4) , final(:, 4) , finalInterp(:, 1), 'nearest');
%
% Remove all redundant data so the data along the profile is strictly
% monotonic
    diffFinal = diff( finalInterp(:, 4) );
    indexRedundant = find(diffFinal <= 0);
    if ~isempty(indexRedundant)
      finalInterp(indexRedundant+1, :) = [];
    end
    nDataInterp = size(finalInterp, 1);
    clear diffFinal indexRedundant
%
%Checking if the temperature is negative
%For negative values, a value of 50 should be added to the absolute value
%of temperature. Requirement of the GTS
    if any( finalInterp(:, 2)<0 )
        tempNeg = find( finalInterp(:, 2) < 0 );
        finalInterp(tempNeg) = abs(finalInterp(tempNeg)) + 50;
    end
    clear tempNeg
%
%Date to be used in the TESAC Message
    V = datevec(final(1,1) + datenum('01-01-1950 00:00:00','dd-mm-yyyy HH:MM:SS'));
    J = num2str(V(1));
%    
%Latitude and Longitude of the profile        
%Quadrant of the globe
    if ( final(1, 3)>0 && final(1, 3)<=180 )
        if (final(1, 2)>0)
            Qc = '1';
        else
            Qc = '3';
        end
    else
        if (final(1, 3) > 180)
            final(1, 3) = 360-final(1, 3);
        end
        if (final(1, 3)<0)
            final(1, 3) = abs(final(1, 3));
        end
        if (final(1, 2)>0)
            Qc = '7';
        else
            Qc = '5';
        end
    end
%    
    profLat = round( abs(final(1, 2)*1000) );
    profLon = round( abs(final(1, 3)*1000) );
%
% platform Code  
    platformCode = 'XXXXX';
%List of WMO number for each glider deployment
listGliderWMO = strcat(outputdir,'/glider_WMO_number.txt');
fid = fopen( listGliderWMO );
    gliderWMO = textscan(fid, '%s %s' );
fclose(fid);   
nWMO = size(gliderWMO,2);
for tt = 1:nWMO
    if ( strcmp(deployment,gliderWMO{1}{tt}) )
       platformCode = gliderWMO{2}{tt};
    end
end
%CHECK if the data is OK to be send to the GTS
%CHECK the latitude longitude values
%Check the time to be not older than 30 days
%Check if the platform code has been filled
okForGTS = 1;
if ( datenum(V) < (datenum(clock)-30) )
    okForGTS = 0;
end
if ( isnan(final(1,2)) || (final(1,2) < -60) || (final(i,2) > -5) )
    okForGTS = 0;
end
if ( isnan(final(1,3)) || (final(1,3) < 90) || (final(i,3) > 175) )
    okForGTS = 0;
end
if ( strcmp(platformCode,'XXXXX') )
    okForGTS = 0;
end
%
%
% Indicator for digitization
% <k1> table 2262 - Standard Depth = 7 OR Inflexion points = 8
    k1 = 7;
% Method of salinity/depth measurement
% <k2> table 2263 - Salinity sensor accuracy better than 0.02 PSU = 2
    k2 = 2;
% Instrument type used for the observation
% Table 1770
    Ix = '830';
% Recorder Type
% Table 4770
    Xr = '99';
%
%% Creation of the TESAC FILE
   if ( okForGTS )
% Open File
    pflag = 'T';
    productidentifier = 'SOFE03';
    oflag = 'C';
    originator = 'AMMC';
    BOMdate = datestr(clock,'yyyymmddHHMMSS');
    filename1 = strcat(TESACoutput, pflag, '_', productidentifier, '_', oflag, '_', originator, '_', BOMdate, '.txt');
    fid = fopen(filename1,'w'); 
%    
%    fprintf(fid, 'ZCZC\r\r\n');
% Section 1    
    fprintf(fid, 'KKYY %02.0f%02.0f%s %02.0f%02.0f/ %s%05.0f %06.0f\r\r\n', V(3), V(2), J(end), V(4), V(5), Qc , profLat, profLon );
% Section 2
    fprintf(fid, '888%1.0f%1.0f %s%s ', k1, k2, Ix, Xr);
%
    ii = 1;
    ostr = '';
    for gg = 1:nDataInterp
        ostr = [ostr sprintf('2%04.0f ', round( abs(finalInterp(gg, 4))) )];
        ostr = [ostr sprintf('3%04.0f ', round( abs(finalInterp(gg, 2)*100)) )];
        if ii == 3
           ostr = [ostr sprintf('4%04.0f',  round( abs(finalInterp(gg, 3)*100)) )];
           fprintf(fid,'%s\r\r\n', ostr);
           ostr = '';
           ii = 1;
        else
           ostr = [ostr sprintf('4%04.0f ',  round( abs(finalInterp(gg, 3)*100)) )];
           ii = ii+1;
        end
    end
%    
    if ~isempty(ostr)
       fprintf(fid, '%s\r\r\n', ostr(1:end-1));
    end
%Section 5
    fprintf(fid, '99999 %s=', platformCode);
% Close file  
    fclose(fid);
    filename2 = strcat(TESACoutput, 'archive/', pflag, '_', productidentifier, '_', oflag, '_', originator, '_', BOMdate, '.txt');
    copyfile(filename1, filename2);
%
  clear nProfileValues data final nDataInterp finalInterp spaceMeter
%
  pause(2);
%
   else
     fid_w = fopen(logfile, 'a');
     fprintf(fid_w,'%s %s %s \r\n',datestr(clock),' Data included in this NetCDF file can not be transmitted to the GTS', filename );
     fclose(fid_w);
   end
%
  end
%
%
end