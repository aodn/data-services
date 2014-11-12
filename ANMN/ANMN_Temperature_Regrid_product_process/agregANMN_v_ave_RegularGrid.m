function [Tstamp,Zgrid,IallV,Lat,Lon,av_window,nValStep] = agregANMN_v_ave_RegularGrid(path2file,flist,variable)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% devVersion of routine to grid Temperature data from ANMN thermistor measurements
%Create an 30min average aggregated product of ANMN temperature logger
% list of all the NetCDF file in the current directory
% INPUT: 	- flist : list of file  %
%			- path2file
%			- variable

%
% OUTPUT: 	- Tstamp	: Time vector
%		 	- Zgrid		: depth grid
%			- IallV		: regridded variable values
%
% BPasquer August 2013
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% initialize time, depth, and parameter matrices
% use time start and end  from NetCDF file name
uscore = regexp(flist(1).name,'_');
tstart =flist(1).name(uscore(3)+1:uscore(4)-1);
tstart(regexp(tstart,'\D'))=[];
tEND = regexp(flist(1).name,'END');
tend = flist(1).name(tEND+3:uscore(8)-1);
tend(regexp(tend,'\D'))=[];
timelapse = ((datenum(tend,'yyyymmddHHMMSS')+1 - datenum(tstart,'yyyymmddHHMMSS'))*86400)/300;

Timeagg = NaN(int16(timelapse),length(flist));
D_agg = NaN(int16(timelapse),length(flist));
V_agg = NaN(int16(timelapse),length(flist));

% GET DATA FROM DEPLOYMENT FILES

% Only need to read one file to get mooring position
Lat = get_var1D(fullfile(path2file,flist(1).name),'LATITUDE');
Lon = get_var1D(fullfile(path2file,flist(1).name),'LONGITUDE');

for n = 1:length(flist)
    
    filename = fullfile(path2file,flist(n).name);
	TIME = get_var1D(filename,'TIME');
	TIME_qc = get_var1D(filename,'TIME_quality_control');	
	DEPTH = get_var1D(filename,'DEPTH');
	DEPTH_qc = get_var1D(filename,'DEPTH_quality_control');
	VARIABLE = get_var1D(filename,variable); 
    VARIABLE = double (VARIABLE); %some data are float instead of double
	VAR_qc = get_var1D(filename,strcat(variable,'_quality_control'));
	
% need to check sample interval at all depths cause some deployments
% have different ones and script not built to process them ( see
% further down)
    sample_int(n) = get_globalAttributes('file',filename,'instrument_sample_interval');	
   
% EXTRACT ONLY GOOD DATA (FLAG=1 OR FLAG=2)
	QC_T	= find(TIME_qc == 1 | TIME_qc == 2);
	QC_D	= find(DEPTH_qc == 1 | DEPTH_qc == 2);
	QC_V	= find(VAR_qc == 1 | VAR_qc == 2);
    
	QC1 	= intersect(QC_T,QC_D);	
	QC      = intersect(QC1,QC_V);
   
	% correction cause some file have bad values wrongly flagged 
    corr = DEPTH(QC)>10 & DEPTH(QC)<10000 ; QC = QC(corr);	
    Timeagg(1:length(QC),n) = TIME(QC) + datenum('01-01-1950 00:00:00');
	D_agg(1:length(QC),n)   = DEPTH(QC);
	V_agg(1:length(QC),n)   = VARIABLE(QC);
	
end

clear  QC_D QC_V  QC QC1 QC_T
clear VAR_qc DEPTH_qc TIME_qc TIME DEPTH VARIABLE

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Check for duplicate sensor/data at same nominal depth
% Duplicates are averaged before  regridding

nomdepth = scan_filename(flist,'nomdepth');
[n,bin] = histc(nomdepth,unique(nomdepth));
duplicate = find(n>1);
if any(n>1) 
    %find  duplicated nomdepth 
    [C,ia,ib] = intersect(nomdepth,unique(nomdepth));%ia give indices of single values :missing indices are duplicates
    [C2,ia2,ib2] = setxor(ia,[1:length(nomdepth)]);
    dupl = nomdepth(C2);
    %average values at same nomdepth. Build new matrice with aggregated
    %values
    
    for nd =1:length(dupl)        
        idx = find(nomdepth==dupl(nd));
        V_av = nanmean(V_agg(:,idx),2);D_av = nanmean(D_agg(:,idx),2);
        % swap values in V_agg with mean values . Will remove one of the
        % duplicate outside of the loop
        V_agg(:,idx) =repmat(V_av,1,2); D_agg(:,idx) = repmat(D_av,1,2); 
        out(nd) = idx(2); %store index of duplicate         
    end
    V_agg(:,out) = [];D_agg(:,out) = []; 
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PREPARE THE TIME VECTOR. 
%Check the sampling interval
sample_interval = unique(sample_int);
if length(sample_interval)>1 
 error ('Deployment has multiple instrument_sample_interval');

end

switch round(sample_interval)
    case {25,50,60} 
        av_window = 30;
        nValStep = 20; %min number of step for valid average

    case {100,120,150}
        av_window = 30;
        nValStep = 10; %min number of step for valid average          
    case 300
        av_window = 30;
        nValStep = 3; %min number of step for valid average		
    case 600
        av_window = 30;
        nValStep = 2;
    case 900
        av_window = 60;
        nValStep = 3;
    case 4800
        av_window = 240;
        nValStep = 2;
end
% Adjust averaging window according to sample interval  and number of valid step
% Timestamp at mid point of averaging time step starting from 

all_dates 	= unique(Timeagg(:));
all_dates(all_dates==0)=[]; %discard 0 if needed
Tst	= min(all_dates); 
Tend 	= max(all_dates); 
st     = 1440/av_window; 
Tvec   = Tst:1/st:Tend; % Time vector of regridded data
Tstamp = Tvec + 1/st/2;

% CHECK NUMBER OF VALID DATA PER AVERAGING WINDOW:
nstep = av_window/(round(sample_interval)/60); % size of averaging window depend on data sampling interval
V_ave = NaN(length(Tvec)-1,size(V_agg,2));
D_ave = NaN(length(Tvec)-1,size(V_agg,2));

for nf = 1:size(V_agg,2) 
    for nst = 1:length(Tvec)-1   
		ii = Timeagg(:,nf) >= Tvec(nst) & Timeagg(:,nf) <= Tvec(nst+1);
		if ~any(ii) ||length(ii==1) <nValStep
% Need minimum number of valid step to calculate mean
			V_ave(nst,nf)  = NaN;
			D_ave(nst,nf)  = NaN;
		else
			V_ave(nst,nf) = nanmean(V_agg(ii,nf));	
			D_ave(nst,nf) = nanmean(D_agg(ii,nf));	
		end
    end	
end
	
clear V_agg D_agg Timeagg
% Depth of sampling 
depthT = unique(round(D_ave(:)));
allV = nan(length(depthT),length(Tvec));
 
% Reorganize depth and temperature matrices
for i = 1:size(V_ave,2)
	for j = 1:length(depthT)
		iAllVj = round(D_ave(:,i)) == depthT(j); %find timestep where depth=depthT
		if any(iAllVj)
			allV(j,iAllVj) = V_ave(iAllVj, i);
		end
	end
	clear iAllVj;
end
% Interpolate allP on Y axis for each value below the first
% non-NaN value
% Interpolate on regular Z grid  with a vertical resolution of 1m.

Zgrid = 0:1:max(depthT(~isnan(depthT)));
IallV = NaN(length(Zgrid),length(Tvec));
for i = 1:length(Tvec)
    iNaN = isnan(allV(:,i));
    iFirstNNan = find(~iNaN, 1, 'first');
    iLastNNan = find(~iNaN, 1, 'last');
    iColumn = ~iNaN;
    iColumn(iFirstNNan:iLastNNan) = true;
   % allP(iColumn, i) = interp1(depthT(~iNaN), allP(~iNaN, i), depthT(iColumn));
    if all(isnan(allV(:, i))) | length(find(iNaN==0))<2
   		IallV(:,i) = NaN;
    else
       	IallV(:,i) = interp1(depthT(~iNaN), allV(~iNaN, i), Zgrid);
    end
end
%replace NaNs with _Fillvalue
for i =  1:length(Tvec)
	IallV(isnan(IallV(:,i)),i) = 999999.;
end

%figure(1)
%pcolor(Tstamp, Zgrid, IallV)
%shading flat
%caxis([12 24])
%ylim([20 105])



 
