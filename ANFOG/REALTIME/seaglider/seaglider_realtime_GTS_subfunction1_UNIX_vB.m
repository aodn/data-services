function [nCycleToProcess, okForGTS] = seaglider_realtime_GTS_subfunction1_UNIX_vB(deployment,filename)
%
%
outputdir = readConfig('output_dir','configGTS.txt');
%OUTPUT: LOG FILE
log = readConfig('log_file','configGTS.txt');
logfile = fullfile(outputdir,log);
%
gtsdir = readConfig('gts_dir','configGTS.txt');
tesacmessagedir = readConfig('tesacmessage_dir','configGTS.txt');
archivedir = readConfig('archive_dir','configGTS.txt');
noaadir = readConfig('noaa_dir','configGTS.txt');
plottingdir = readConfig('plotting_dir','configGTS.txt');
%
TESACoutput = fullfile(outputdir, gtsdir, deployment, tesacmessagedir);
if (~exist(TESACoutput,'dir'))
    mkdir( TESACoutput );
end
%
if (~exist( fullfile(TESACoutput, archivedir),'dir'))
    mkdir( fullfile(TESACoutput, archivedir) );
end
%
if (~exist( fullfile(TESACoutput, noaadir),'dir'))
    mkdir( fullfile(TESACoutput, noaadir) );
end
%
netcdfToProcess = fullfile(outputdir, plottingdir, deployment, filename);
%
nc = netcdf.open(netcdfToProcess, 'NC_NOWRITE');
VAR ={'TIME','LATITUDE','LONGITUDE','DEPTH','TEMP','PSAL','DEPTH_quality_control','TEMP_quality_control', 'PSAL_quality_control'};
%
for nvar = 1:length(VAR)
    temp_varid = netcdf.inqVarID(nc,cell2mat(VAR(nvar)));
    temp = netcdf.getVar(nc, temp_varid);
    varname = genvarname(cell2mat(VAR(nvar)));
    eval([varname '= temp(:);']);
    clear temp
end  
netcdf.close(nc);        
%
%NUMBER OF DATA POINTS INCLUDED IN THE FILE
%
nValues = size(DEPTH,1);
%
%USE OF THE FUNCTION 'DIFF' TO CALCULATE THE DIFFERENCES BETWEEN ADJACENT
%ELEMENTS OF DEPTH
%THE RESULT IS A VECTOR WITH A SIZE EQUAL TO (nValues-1)
temp = (DEPTH(:) == 99999 );
if (~isempty(temp))
   DEPTH(temp) = NaN;
end
clear temp
diffDepth = diff(DEPTH);
%
%SEARCH FOR POSITIVE VALUES OF THE DIFFERENCE OF DEPTH
%THE VALUES IS EQUAL TO 1 IF THE DIFFERENCE IN DEPTH IS POSITIVE
%AND IS EQUAL TO 0 IF THE DIFFERENCE IN DEPTH IS NEGATIVE
positives = diffDepth >= 0;
%
%CALCULATE THE DIFFERENCE BETWEEN ADJACENT ELEMENTS OF POSITIVES
%THE RESULTS IS A VECTOR WITH A SIZE EQUAL TO (nValues - 2)
diffProfile = diff(positives);
%
%INDEX WHERE THE GLIDER IS CHANGING DIRECTION (GOING UPWARD OR DOWNWARD)
%FIND THE VALUES EQUAL TO 1 OR -1 IN THE VECTOR diffProfile
%
turnPoint = find(diffProfile == 1 | diffProfile == -1) + 1;
%
%NTURNPOINT REPRESENTS THE NUMBER OF TIMES WHERE THE GLIDER IS CHANGING
%DIRECTION
if (~isempty(turnPoint))
    nTurnPoint = size(turnPoint, 1);
end
%
%CREATION OF A MATRIX 'INDEXCYCLE' TO STORE THE INDEX OF THE START AND END
%OF EACH PROFILE PERFORMED BY THE GLIDER.
%EACH ROW REPRESENT ONE PROFILE
%FIRST COLUMN: INDEX OF THE START OF THE PROFILE
%SECOND COLUMN: INDEX OF THE END OF THE PROFILE
%THIRD COLUM: NUMBER OF DATA POINTS MINUS 1 FOR EACH PROFILE
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
%NUMBERS OF ASCENT AND DESCENT
nCycle = size(indexCycle, 1);
%
%INDEX OF CYCLES GOOD FOR PROCESSING.
%SOMETIMES THE GLIDER IS DOING SOME UP AND DOWN NEAR THE SURFACE.
%THE THIRD COLUM OF THE VECTOR INDEXCYCLE IS A GOOD INDICATOR OF WHICH
%PROFILES ARE GOOD FOR PROCESSING
%IF THE NUMBER OF DATA FOR A PROFILE IS LESS THAN 10, I DO NOT PROCESS IT
cycleToProcess  = find(indexCycle(:, 3) > 10);
%
%
if ( ~isempty(cycleToProcess) )
	nCycleToProcess = size(cycleToProcess, 1);
%
	for i = 1:nCycleToProcess  
%NUMBER OF DATA POINTS FOR EACH PROFILE      
		nProfileValues = ( indexCycle(cycleToProcess(i),2) - indexCycle(cycleToProcess(i),1) ) + 1;
%CREATION OF THE MATRIX data TO STORE THE VALUES OF EACH VARIABLE FOR THE 
%CORRESPONDING PROFILE    
		data  = NaN(nProfileValues, 9);
%
		for nvar = 1:length(VAR)
			varname = genvarname(cell2mat(VAR(nvar)));
			eval(['data(:,nvar) =' varname '(indexCycle(cycleToProcess(i),1) : indexCycle(cycleToProcess(i),2));']);
		end
%     
%REPLACE FILLVALUE BY NAN
		temp = (data(:, 4) == 99999 | data(:, 5) == 99999 | data(:, 6) == 99999);
		data(temp, :) = NaN;
		clear temp
%USE THE QUALITY CONTROL INFORMATION TO ONLY USE GOOD DATA
		qcTest = (data(:, 7) ~=1 | data(:, 8) ~=1 | data(:, 9) ~=1);
		data(qcTest, :) = NaN;
		clear qcTest
%
%KEEP ONLY LINES WITH GOOD DATA
		Flog  = (~isnan(data(:,1)));
		nData = sum(Flog);
%CREATION OF THE MATRIX final 
%TIME:1, LATITUDE:2, LONGITUDE:3, DEPTH:4, TEMPERATURE:5, SALINITY:6 
%
		final = NaN(nData, 6);
		for nvar = 1:6
			final(:, nvar)  = data(Flog, nvar); 
		end 
		clear Flog nData
%
%TEST IF THE PROFILE IS ACENDING OR DESCENDING
%IF THE PROFILE IS ACENDING THEN WE TRANSPOSE THE VECTOR
%
		profileType = (final(2, 4) - final(1, 4));
		if (profileType < 0) %ascending profile
			final = final(end:-1:1, :);
		end
		clear profileType
%
%AVERAGE OF THE DEPTH DIFFERENCE 
%I WILL ONLY INCLUDE DATA EVERY 2 METERS OR MORE IN THE TESAC MESSAGE
		diffDepthProfile = diff(final(:, 4));
		indexRedundant = find(diffDepthProfile <= 0);
		if ~isempty(indexRedundant)
		  final(indexRedundant+1, :) = [];
		end
		clear indexRedundant 
		spaceMeter = max(2, round(mean(abs(diffDepthProfile))));
%NUMBER OF DATA POINTS TO INCLUDE IN THE TESAC MESSAGE
		nDataInterp = floor((floor(final(end, 4)) - ceil(final(1, 4)))/spaceMeter) + 1;
% CHECK IF THE NUMBER OF THE DATA IS LESS THAN 740
% IN ORDER TO HAVE A MESSAGE WITH A SIZE < 15 KB (REQUIREMENT OF THE GTS)
% IF IT IS OVER 740 THEN I KEEP THE SAME AMOUNT OF DATA UNTIL 300 METERS
% AND I SUBSET BELOW THAT DEPTH UNTIL THE BOTTOM
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
%DATA FROM THE SURFACE TO THE MEDIUMDEPTH          
			  nDataInterp1 = floor((mediumDepth - ceil(final(1,4)))/spaceMeter) + 1;
			  finalInterp(1:nDataInterp1, 1) = ceil(final(1, 4)) : spaceMeter : mediumDepth;
%DATA FROM THE MEDIUMDEPTH TO THE BOTTOM          
			  nDataInterp2 = floor((floor(final(end,4)) - (finalInterp(nDataInterp1,1) + spaceMeter + ll)) / (spaceMeter+ll)) + 1;
			  finalInterp(nDataInterp1+1 : nDataInterp1+nDataInterp2, 1) = finalInterp(nDataInterp1, 1) + spaceMeter+ll : spaceMeter+ll : floor(final(end,4));
			  ll = ll+1;
			end
		end
		clear nDataInterp1 nDataInterp2 ll
% USE THE FUNCTION 'interp1' TO FIND THE NEAREST VALUES FOR EACH VARIABLE
% (Depth, Temperature and Salinity) FOR THE SELECTED DEPTH.
		finalInterp(:,2) = interp1(final(:, 4) , final(:, 5) , finalInterp(:, 1), 'nearest');
		finalInterp(:,3) = interp1(final(:, 4) , final(:, 6) , finalInterp(:, 1), 'nearest');
		finalInterp(:,4) = interp1(final(:, 4) , final(:, 4) , finalInterp(:, 1), 'nearest');
%
% REMOVE ALL REDUNDANT DATA SO THE DATA ALONG THE PROFILE IS STRICTLY
% MONOTONIC
		diffFinal = diff( finalInterp(:, 4) );
		indexRedundant = find(diffFinal <= 0);
		if ~isempty(indexRedundant)
		  finalInterp(indexRedundant+1, :) = [];
		end
		nDataInterp = size(finalInterp, 1);
		clear diffFinal indexRedundant
%
%CHECKING IF THE TEMPERATURE IS NEGATIVE
%FOR NEGATIVE VALUES, A VALUE OF 50 SHOULD BE ADDED TO THE ABSOLUTE VALUE
%OF TEMPERATURE. REQUIREMENT OF THE GTS
		if any( finalInterp(:, 2)<0 )
			tempNeg = find( finalInterp(:, 2) < 0 );
			finalInterp(tempNeg) = abs(finalInterp(tempNeg)) + 50;
		end
		clear tempNeg
%
%DATE TO BE USED IN THE TESAC MESSAGE
		V = datevec(final(1,1) + datenum('01-01-1950 00:00:00','dd-mm-yyyy HH:MM:SS'));
		J = num2str(V(1));
%    
%LATITUDE AND LONGITUDE OF THE PROFILE        
%QUADRANT OF THE GLOBE
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
% PLATFORM CODE  
		platformCode = 'XXXXX';
%LIST OF WMO NUMBER FOR EACH GLIDER DEPLOYMENT
		gliderWMOfile = readConfig('glider_WMO_file', 'configGTS.txt');
        currentdir = readConfig('current_dir', 'configGTS.txt');
		listGliderWMO = fullfile(currentdir,gliderWMOfile);
		fid = fopen( listGliderWMO );
		gliderWMO = textscan(fid, '%s %s' );
		fclose(fid);   
		nWMO = size(gliderWMO{1},1);
		for tt = 1:nWMO
			if ( strcmp(deployment,gliderWMO{1}{tt}) )
			   platformCode = gliderWMO{2}{tt};
			end
		end
%CHECK IF THE DATA IS OK TO BE SENT TO THE GTS
%CHECK THE LATITUDE LONGITUDE VALUES
%CHECK THE TIME TO BE NOT OLDER THAN 29 DAYS
%CHECK IF THE PLATFORM CODE HAS BEEN FILLED
		okForGTS = 1;
		if ( datenum(V) < (datenum(clock)-29) )
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
% INDICATOR FOR DIGITIZATION
% <k1> table 2262 - Standard Depth = 7 OR Inflexion points = 8
		k1 = readConfig('k1','configGTS.txt');
% METHOD OF SALINITY/DEPTH MEASUREMENT
% <k2> table 2263 - Salinity sensor accuracy better than 0.02 PSU = 2
		k2 = readConfig('k2','configGTS.txt');
% INSTRUMENT TYPE USED FOR THE OBSERVATION
% TABLE 1770
		Ix = readConfig('Ix','configGTS.txt');
% RECORDER TYPE
% TABLE 4770
		Xr = readConfig('Xr','configGTS.txt');
%
%% CREATION OF THE TESAC FILE
	   if ( okForGTS )
% OPEN FILE
		pflag = readConfig('pflag','configGTS.txt');
		productidentifier = readConfig('productidentifier','configGTS.txt');
		oflag = readConfig('oflag','configGTS.txt');
		originator = readConfig('originator','configGTS.txt');
%TIME IN UTC FOR FILENAME    
		localTime = datenum(clock);
		MelTimeZone(1,1) = datenum('04-04-2010 03:00:00', 'dd-mm-yyyy HH:MM:SS');
		MelTimeZone(1,2) = datenum('03-10-2010 02:00:00', 'dd-mm-yyyy HH:MM:SS');
		MelTimeZone(2,1) = datenum('03-04-2011 03:00:00', 'dd-mm-yyyy HH:MM:SS');
		MelTimeZone(2,2) = datenum('02-10-2011 02:00:00', 'dd-mm-yyyy HH:MM:SS');
		MelTimeZone(3,1) = datenum('01-04-2012 03:00:00', 'dd-mm-yyyy HH:MM:SS');
		MelTimeZone(3,2) = datenum('07-10-2012 02:00:00', 'dd-mm-yyyy HH:MM:SS');
		MelTimeZone(4,1) = datenum('07-04-2013 03:00:00', 'dd-mm-yyyy HH:MM:SS');
		MelTimeZone(4,2) = datenum('06-10-2013 02:00:00', 'dd-mm-yyyy HH:MM:SS');
		if ( ((localTime > MelTimeZone(1,1))&& (localTime < MelTimeZone(1,2))) ||  ((localTime > MelTimeZone(2,1))&& (localTime < MelTimeZone(2,2))) || ((localTime > MelTimeZone(3,1))&& (localTime < MelTimeZone(3,2))) || ((localTime > MelTimeZone(4,1))&& (localTime < MelTimeZone(4,2))))
		   timeZone = 10;
		else
		   timeZone = 11;
		end
%    
		BOMdate = datestr( datenum(clock)-(timeZone/24),'yyyymmddHHMMSS');
		filename1 = fullfile(TESACoutput, strcat(pflag, '_', productidentifier, '_', oflag, '_', originator, '_', BOMdate, '.txt'));
		fid = fopen(filename1,'w'); 
%    
%    fprintf(fid, 'ZCZC\r\r\n');
% Section 1    
		fprintf(fid, 'KKYY %02.0f%02.0f%s %02.0f%02.0f/ %s%05.0f %06.0f\r\r\n', V(3), V(2), J(end), V(4), V(5), Qc , profLat, profLon );
% Section 2
		fprintf(fid, '888%1.0f%1.0f %s%s ', str2num(k1), str2num(k2), Ix, Xr);
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
%SECTION 5
		fprintf(fid, '99999 %s=', platformCode);
% CLOSE FILE  
		fclose(fid);
		filename2 = fullfile(TESACoutput, archivedir, strcat(pflag, '_', productidentifier, '_', oflag, '_', originator, '_', BOMdate, '.txt'));
		filename3 = fullfile(TESACoutput, noaadir, strcat(pflag, '_', productidentifier, '_', oflag, '_', originator, '_', BOMdate, '.txt'));
		copyfile(filename1, filename2);
		copyfile(filename1, filename3);
%
	  clear nProfileValues data final nDataInterp finalInterp spaceMeter
%
	  pause(2);
%
	   else
		 message = get_reportmessageGTS(9);
		 print_message(logfile, message, filename);
	   end
%
	end
%
%
end