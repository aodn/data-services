% AGGREGATE_ARGO
%
% INPUT ARG: 
%   replace  1=build new files even if they already exist  [default is 1]
%            Use 0 if this code crashed before all files were built, so we
%            can skip rebuilding those files already successfully built. 
%            Remove the last-built file if the crash happened prior to the
%            "succesfully written" message, as this file might be corrupted.
%
% FILE INPUTS: netcdf files and argo_desc.mat in usmirror
%
% FILE OUTPUTS: time/space aggregated profiles in netCDF files. Two sets of files:
%     1) normal low-res sampling Argos profiles
%     2) hi-res sampling Iridium profiles
%
% CALLED BY:  user
%
% CALLS: no code outside of this file, apart from netcdf libraries
%
% AUTHOR: J Dunn 15/9/2011
%
% MODS:  
%
% USAGE: aggregate_argo(replace)

function aggregate_argo(replace)

dbclear if warning
   
if nargin==0 || isempty(replace)
   replace = 1;
end

pth = '/home/argo/data/usmirror/';
opth = '/home/datalib/observations/argo/aggregated/';

% Argo data description file is created by the GDAC download process
if ~exist([pth 'argo_desc.mat'],'file')
   disp(['Cannot find ' pth 'argo_desc.mat -  ABORTING'])
   return
end
AD = load([pth 'argo_desc']);

nowyr = datevec(now);
nowyr = nowyr(1);
yrs = datevec(AD.serial_date);
yrs = yrs(:,1);
yrs(yrs<1995) = nan;
yrs(yrs>nowyr) = nan;

% Regions: 1=Atlantic  2=Nth Pac  3=S Pac  4=Indian
regnam = {'atlantic','nth_pac','sth_pac','indian'};

xrgn = {[290 290 283 282 280.52 278.78 277.45 275.11 273.37 265.26 260 260 ...
	 460 460 404 404 395.9 390 390], ...
	[290 290 283 282 280.52 278.78 277.45 275.11 273.37 265.26 260 260 ...
	 100 100], ...
	[130.3 131 135.2 142.4 142.4 150 150 290 290], ...
	[100 44 44 35.9 30 30 150 150 142.4 142.4 135.2 131 130.3 100]};

yrgn = {[-90 8 8 8.78 9.23 8.35 8.94 11.03 13.91 17.21 20 90 90 50 50 38.7 30 30 -80],...
	[0 8 8 8.78 9.23 8.35 8.94 11.03 13.91 17.21 20 90 90 0],...
	[0 -1.2 -3.9 -7 -30 -30 -90 -90 0], ...
	[50 50 38.7 30 30 -80 -80 -30 -30 -7 -3.9 -1.2 0 0]};

% "used" is used to clobber longitude of previously selected profiles so they
% are not included in more than one region file (as might happen if they are on
% the region boundary
used = zeros(size(AD.lon));

% Loop through each region, and each year within regions, to select profiles
% to collate.

for ir = 1:length(xrgn)
   lo = AD.lon;   
   if any(xrgn{ir}>360)
      jj = lo<180;
      lo(jj) = lo(jj)+360;
   end
   lo(~~used) = nan;
   
   inr = find(inpolygon(lo,AD.lat,xrgn{ir},yrgn{ir}));
   used(inr) = 1;
   
for iyr = 1996:nowyr
      fnm = [opth 'argo_' regnam{ir} '_' num2str(iyr)];
      if replace || ~exist([fnm '.nc'],'file')
	 iny = inr(find(yrs(inr)==iyr));
	 if ~isempty(iny)
	    write_nc_yr(AD,iny,fnm);
	 end
      end
   end
end

return

%-----------------------------------------------------------------------------
function write_nc_yr(AD,iny,fnm)


pth = '/home/argo/data/usmirror/';

% Set number of obs which determines whether profile belongs in high or
% low vertical sampling (Iridium or Argos) file.
maxob = 150;  

getraw = 0;   % Are raw obs required as well as ADJUSTED profiles ?

% Preallocate accumulation arrays and load in all non-empty profiles
% which have vertical sampling appropriate to this stage
nn = length(iny);
disp(['Scanning ' num2str(nn) ' files for ' fnm]);

ndep = 1;
if getraw
   t = nan(nn,ndep);
   s = nan(nn,ndep);
   p = nan(nn,ndep);
   tqc = zeros(nn,ndep,'int16');
   sqc = zeros(nn,ndep,'int16');
   pqc = zeros(nn,ndep,'int16');
end
ta = nan(nn,ndep);
sa = nan(nn,ndep);
pa = nan(nn,ndep);
tae = nan(nn,ndep);
sae = nan(nn,ndep);
pae = nan(nn,ndep);
taqc = zeros(nn,ndep,'int16');
saqc = zeros(nn,ndep,'int16');
paqc = zeros(nn,ndep,'int16');

prnum = zeros(nn,1,'int16');
juld = nan(nn,1);
date_cr = nan(nn,1);
date_up = nan(nn,1);
lon = nan(nn,1);
lat = nan(nn,1);
platnum = zeros(nn,1,'int32');
dirn = repmat(' ',nn,1);
data_mode = repmat(' ',nn,1);
datacentre = repmat('  ',nn,1);
dsi = repmat('    ',nn,1);
inst_ref = repmat(' ',nn,64);
hbookver = repmat('    ',nn,1);

stg = ones(1,nn);
max1 = 0;  max2 = 0;
mm = 0;

for ii = 1:nn
   jny = iny(ii);
   afnm = [pth  AD.dac_dirs{AD.data_centre_id(jny)} '/' ...
	   num2str(AD.wmo_id(jny)) '/profiles/' AD.file_name{jny}];
   
   dirl = dir(afnm);
   if dirl.bytes<1000
      P = [];
      disp([AD.file_name{jny} ' is empty'])
   else
      P = get_prof_nc(afnm,getraw);
   end
   
   if isempty(P)
      nob = 0;
   elseif getraw
      nr = find(~isnan(P.p) & (~isnan(P.t) | ~isnan(P.s)),1,'last');
      if isempty(nr); nr = 0; end
      nc = find(~isnan(P.pa) & (~isnan(P.ta) | ~isnan(P.sa)),1,'last');
      if isempty(nc); nc = 0; end
      nob = max([nr nc]);
   else
      nc = find(~isnan(P.pa) & (~isnan(P.ta) | ~isnan(P.sa)),1,'last');
      if isempty(nc); nc = 0; end
      nob = nc;      
   end
   
   if nob>0
      if nob>ndep
	 if getraw
	    t(:,(ndep+1):nob) = nan;
	    s(:,(ndep+1):nob) = nan;
	    p(:,(ndep+1):nob) = nan;
	    tqc(:,(ndep+1):nob) = 0;
	    sqc(:,(ndep+1):nob) = 0;
	    pqc(:,(ndep+1):nob) = 0;
	 end
	 ta(:,(ndep+1):nob) = nan;
	 sa(:,(ndep+1):nob) = nan;
	 pa(:,(ndep+1):nob) = nan;
	 tae(:,(ndep+1):nob) = nan;
	 sae(:,(ndep+1):nob) = nan;
	 pae(:,(ndep+1):nob) = nan;
	 taqc(:,(ndep+1):nob) = 0;
	 saqc(:,(ndep+1):nob) = 0;
	 paqc(:,(ndep+1):nob) = 0;
	 ndep = nob;
      end

      mm = mm+1;
      if nob>maxob
	 stg(mm) = 2;
	 max2 = max([max2 nob]);
      else
	 max1 = max([max1 nob]);	 
      end

      if getraw
	 t(mm,1:nr) = P.t(1:nr);
	 s(mm,1:nr) = P.s(1:nr);
	 p(mm,1:nr) = P.p(1:nr);
	 tqc(mm,1:nr) = P.tqc(1:nr);
	 sqc(mm,1:nr) = P.sqc(1:nr);
	 pqc(mm,1:nr) = P.pqc(1:nr);
      end
      
      ta(mm,1:nc) = P.ta(1:nc);
      sa(mm,1:nc) = P.sa(1:nc);
      pa(mm,1:nc) = P.pa(1:nc);
      tae(mm,1:nc) = P.tae(1:nc);
      sae(mm,1:nc) = P.sae(1:nc);
      pae(mm,1:nc) = P.pae(1:nc);
      taqc(mm,1:nc) = P.taqc(1:nc);
      saqc(mm,1:nc) = P.saqc(1:nc);
      paqc(mm,1:nc) = P.paqc(1:nc);

      prnum(mm) = P.profile_number;
      juld(mm) = P.serial_date;
      lon(mm) = P.lon;
      lat(mm) = P.lat;
      platnum(mm) = P.float;
      dirn(mm) = P.dirn;
      datacentre(mm,:) = P.dc;
      data_mode(mm) = P.dmode;
      dsi(mm,:) = P.dsi;
      date_cr(mm) = P.date_cr;
      date_up(mm) = P.date_up;
      hbookver(mm,:) = P.handbookv;
      inst_ref(mm,:) = P.inst_ref;
   end
end

if mm==0
   return
end

%DEBUG: save temp_all

% ------- Create and populate new files

for istg = unique(stg(1:mm))
   jj = find(stg(1:mm)==istg);

   if istg==1
      ndep = max1;
   else
      ndep = max2;
      fnm = [fnm '_hires'];
   end   
   disp([fnm ' : ' num2str(length(jj)) ' profiles, up to ' num2str(ndep) ...
	' obs']);

   disp('a')
   nco = netcdf([fnm '.nc'], 'clobber');

   % Global attributes
   if istg==1
      nco.description = ['Argo aggregation file - normal vertical sampling' ...
			 ' density (Argos) profiles'];
   else
      nco.description = ['Argo aggregation file - high vertical sampling' ...
			 ' density (Iridium) profiles'];
   end
   nco.author = 'Jeff Dunn';
   nco.date = datestr(now);
   nco.history = ['Created by aggregate_argo.m on ' date];
   %nco.url = 'http://www.argodatamgt.org/Documentation';
   nco.url = 'http://www.cmar.csiro.au/argo/';
   % An IMOS page instead? Needs to describe how to use Argo data!
   nco.comment = ...
       ['Quality flags and Error estimates should be taken into account' ...
	' when using this data. See Argo User Manual. Format of this file' ...
	' differs from single-profile files: many variables left out, and' ...
       ' PLATFORM_NUMBER, DATE_UPDATE, DATE_CREATE and all _QC vars changed ' ...
	'from char to numeric.'];
   
   fillval = 99999;
   disp('b')

   % Define dimensions
   nco('N_PROF') = length(jj);   
   nco('N_LEVELS')   = ndep;
   nco('STRING2')   = 2;
   nco('STRING4')   = 4;
   nco('STRING64')   = 64;

   % Define variables
   if getraw
      nco{'TEMP'}  = ncfloat('N_PROF','N_LEVELS');
      nco{'PSAL'}  = ncfloat('N_PROF','N_LEVELS');
      nco{'PRES'}  = ncfloat('N_PROF','N_LEVELS');
      nco{'TEMP_QC'}  = ncint('N_PROF','N_LEVELS');
      nco{'PSAL_QC'}  = ncint('N_PROF','N_LEVELS');
      nco{'PRES_QC'}  = ncint('N_PROF','N_LEVELS');
   end
   nco{'TEMP_ADJUSTED'}  = ncfloat('N_PROF','N_LEVELS');
   nco{'PSAL_ADJUSTED'}  = ncfloat('N_PROF','N_LEVELS');
   nco{'PRES_ADJUSTED'}  = ncfloat('N_PROF','N_LEVELS');
   nco{'TEMP_ADJUSTED_QC'}  = ncint('N_PROF','N_LEVELS');
   nco{'PSAL_ADJUSTED_QC'}  = ncint('N_PROF','N_LEVELS');
   nco{'PRES_ADJUSTED_QC'}  = ncint('N_PROF','N_LEVELS');
   nco{'TEMP_ADJUSTED_ERROR'}  = ncfloat('N_PROF','N_LEVELS');
   nco{'PSAL_ADJUSTED_ERROR'}  = ncfloat('N_PROF','N_LEVELS');
   nco{'PRES_ADJUSTED_ERROR'}  = ncfloat('N_PROF','N_LEVELS');

   nco{'CYCLE_NUMBER'}  = ncint('N_PROF');
   nco{'LONGITUDE'}   = ncfloat('N_PROF');
   nco{'LATITUDE'}    = ncfloat('N_PROF');
   nco{'PLATFORM_NUMBER'} = ncint('N_PROF');
   nco{'DIRECTION'}   = ncchar('N_PROF');
   nco{'DATA_CENTRE'} = ncchar('N_PROF','STRING2');
   nco{'DATA_STATE_INDICATOR'} = ncchar('N_PROF','STRING4');
   nco{'HANDBOOK_VERSION'} = ncchar('N_PROF','STRING4');
   nco{'INST_REFERENCE'} = ncchar('N_PROF','STRING64');
   nco{'JULD'}        = ncfloat('N_PROF');
   nco{'DATE_CREATION'} = ncfloat('N_PROF');
   nco{'DATE_UPDATE'}   = ncfloat('N_PROF');
   nco{'DATA_MODE'}   = ncchar('N_PROF');

   disp('c')

   % Define variable attributes
   if getraw
      nco{'TEMP'}.long_name  = 'SEA TEMPERATURE IN SITU ITS-90 SCALE';
      nco{'TEMP'}.units      = 'degree_Celsius';
      nco{'TEMP'}.FillValue_ = ncfloat(fillval);
      nco{'TEMP'}.valid_min  = ncfloat(-2);
      nco{'TEMP'}.valid_max  = ncfloat(40);
      nco{'TEMP'}.comment = 'In situ measurement';

      nco{'TEMP_QC'}.long_name  = 'quality flag';
      nco{'TEMP_QC'}.conventions = 'Argo reference table 2';
      nco{'TEMP_QC'}.FillValue_ = ' ';

      nco{'PRES'}.long_name  = 'SEA PRESSURE';
      nco{'PRES'}.units      = 'decibar';
      nco{'PRES'}.FillValue_ = ncfloat(fillval);
      nco{'PRES'}.valid_min  = ncfloat(-100);
      nco{'PRES'}.valid_max  = ncfloat(12000);
      nco{'PRES'}.comment = 'In situ measurement';

      nco{'PRES_QC'}.long_name  = 'quality flag';
      nco{'PRES_QC'}.conventions = 'Argo reference table 2';
      nco{'PRES_QC'}.FillValue_ = ' ';

      nco{'PSAL'}.long_name  = 'PRACTICAL SALINITY';
      nco{'PSAL'}.units      = 'psu';
      nco{'PSAL'}.FillValue_ = ncfloat(fillval);
      nco{'PSAL'}.valid_min  = ncfloat(0);
      nco{'PSAL'}.valid_max  = ncfloat(42);
      nco{'PSAL'}.comment = 'In situ measurement';

      nco{'PSAL_QC'}.long_name  = 'quality flag';
      nco{'PSAL_QC'}.conventions = 'Argo reference table 2';
      nco{'PSAL_QC'}.FillValue_ = ' ';
   end

   nco{'TEMP_ADJUSTED'}.long_name  = 'SEA TEMPERATURE IN SITU ITS-90 SCALE';
   nco{'TEMP_ADJUSTED'}.units      = 'degree_Celsius';
   nco{'TEMP_ADJUSTED'}.FillValue_ = ncfloat(fillval);
   nco{'TEMP_ADJUSTED'}.valid_min  = ncfloat(-2);
   nco{'TEMP_ADJUSTED'}.valid_max  = ncfloat(40);
   nco{'TEMP_ADJUSTED'}.comment = 'In situ measurement after applying known corrections';

   nco{'TEMP_ADJUSTED_QC'}.long_name  = 'quality flag';
   nco{'TEMP_ADJUSTED_QC'}.conventions = 'Argo reference table 2';
   nco{'TEMP_ADJUSTED_QC'}.FillValue_ = ' ';

   nco{'TEMP_ADJUSTED_ERROR'}.long_name  = 'SEA TEMPERATURE IN SITU ITS-90 SCALE';
   nco{'TEMP_ADJUSTED_ERROR'}.units      = 'degree_Celsius';
   nco{'TEMP_ADJUSTED_ERROR'}.FillValue_ = ncfloat(fillval);
   nco{'TEMP_ADJUSTED_ERROR'}.valid_min  = ncfloat(0);
   nco{'TEMP_ADJUSTED_ERROR'}.valid_max  = ncfloat(40);
   nco{'TEMP_ADJUSTED_ERROR'}.comment = 'The error on the adjusted values as determined by the delayed mode QC process.';


   nco{'PRES_ADJUSTED'}.long_name  = 'SEA PRESSURE';
   nco{'PRES_ADJUSTED'}.units      = 'decibar';
   nco{'PRES_ADJUSTED'}.FillValue_ = ncfloat(fillval);
   nco{'PRES_ADJUSTED'}.valid_min  = ncfloat(-100);
   nco{'PRES_ADJUSTED'}.valid_max  = ncfloat(12000);
   nco{'PRES_ADJUSTED'}.comment = 'In situ measurement after applying known corrections';

   nco{'PRES_ADJUSTED_QC'}.long_name  = 'quality flag';
   nco{'PRES_ADJUSTED_QC'}.conventions = 'Argo reference table 2';
   nco{'PRES_ADJUSTED_QC'}.FillValue_ = ' ';

   nco{'PRES_ADJUSTED_ERROR'}.long_name  = 'SEA PRESSURE';
   nco{'PRES_ADJUSTED_ERROR'}.units      = 'decibar';
   nco{'PRES_ADJUSTED_ERROR'}.FillValue_ = ncfloat(fillval);
   nco{'PRES_ADJUSTED_ERROR'}.valid_min  = ncfloat(0);
   nco{'PRES_ADJUSTED_ERROR'}.valid_max  = ncfloat(12000);
   nco{'PRES_ADJUSTED_ERROR'}.comment = 'The error on the adjusted values as determined by the delayed mode QC process.';


   nco{'PSAL_ADJUSTED'}.long_name  = 'PRACTICAL SALINITY';
   nco{'PSAL_ADJUSTED'}.units      = 'psu';
   nco{'PSAL_ADJUSTED'}.FillValue_ = ncfloat(fillval);
   nco{'PSAL_ADJUSTED'}.valid_min  = ncfloat(0);
   nco{'PSAL_ADJUSTED'}.valid_max  = ncfloat(42);
   nco{'PSAL_ADJUSTED'}.comment = 'In situ measurement after applying known corrections';

   nco{'PSAL_ADJUSTED_QC'}.long_name  = 'quality flag';
   nco{'PSAL_ADJUSTED_QC'}.conventions = 'Argo reference table 2';
   nco{'PSAL_ADJUSTED_QC'}.FillValue_ = ' ';

   nco{'PSAL_ADJUSTED_ERROR'}.long_name  = 'PRACTICAL SALINITY';
   nco{'PSAL_ADJUSTED_ERROR'}.units      = 'psu';
   nco{'PSAL_ADJUSTED_ERROR'}.FillValue_ = ncfloat(fillval);
   nco{'PSAL_ADJUSTED_ERROR'}.valid_min  = ncfloat(0);
   nco{'PSAL_ADJUSTED_ERROR'}.valid_max  = ncfloat(42);
   nco{'PSAL_ADJUSTED_ERROR'}.comment = 'The error on the adjusted values as determined by the delayed mode QC process.';


   nco{'LONGITUDE'}.long_name = 'Longitude of the station, best estimate';
   nco{'LONGITUDE'}.units = 'Degrees E';
   nco{'LONGITUDE'}.FillValue_ = ncfloat(fillval);
   nco{'LONGITUDE'}.valid_min = 0. ;
   nco{'LONGITUDE'}.valid_max = 360. ;

   nco{'LATITUDE'}.long_name = 'Latitude of the station, best estimate';
   nco{'LATITUDE'}.units = 'Degrees N';
   nco{'LATITUDE'}.FillValue_ = ncfloat(fillval);
   nco{'LATITUDE'}.valid_min = -90. ;
   nco{'LATITUDE'}.valid_max = 90. ;

   nco{'DATA_CENTRE'}.long_name = 'Data centre in charge of float data processing' ;
   nco{'DATA_CENTRE'}.conventions = 'Argo reference table 4' ;
   nco{'DATA_CENTRE'}.FillValue_ = ' ' ;

   nco{'DATA_MODE'}.long_name = 'Delayed mode or real time data' ;
   nco{'DATA_MODE'}.conventions = ...
       'R : real time; D : delayed mode; A : real time with adjustment' ;
   nco{'DATA_MODE'}.FillValue_ = ' ' ;

   nco{'DATA_STATE_INDICATOR'}.long_name = 'Degree of processing the data have passed through' ;
   nco{'DATA_STATE_INDICATOR'}.conventions = 'Argo reference table 6' ;
   nco{'DATA_STATE_INDICATOR'}.FillValue_ = ' ' ;

   nco{'DIRECTION'}.long_name = 'Direction of the station profiles' ;
   nco{'DIRECTION'}.conventions = 'A: ascending profiles, D: descending profiles' ;
   nco{'DIRECTION'}.FillValue_ = ' ' ;

   nco{'HANDBOOK_VERSION'}.comment = 'Data handbook version' ;
   nco{'HANDBOOK_VERSION'}.FillValue_ = ' ' ;

   nco{'PLATFORM_NUMBER'}.long_name = 'Float unique identifier' ;
   nco{'PLATFORM_NUMBER'}.conventions = 'WMO float identifier number' ;
   nco{'PLATFORM_NUMBER'}.FillValue_ = -fillval;

   nco{'CYCLE_NUMBER'}.long_name = 'Float cycle number' ;
   nco{'CYCLE_NUMBER'}.conventions = '0..N, 0 : launch cycle (if exists), 1 : first complete cycle';
   nco{'CYCLE_NUMBER'}.FillValue_ = fillval;

   nco{'JULD'}.long_name = 'Julian day (UTC) of the station' ;
   nco{'JULD'}.units = 'days since 1950-01-01 00:00:00 UTC';
   nco{'JULD'}.conventions = ...
       'Relative julian days with decimal part (as parts of day)';		    
   nco{'JULD'}.FillValue_ = ncfloat(-fillval);

   nco{'DATE_CREATION'}.long_name = 'Date of file creation' ;
   nco{'DATE_CREATION'}.units = 'days since 1950-01-01 00:00:00 UTC';
   nco{'DATE_CREATION'}.comment = ...
       'Date of profile file, not of this aggregation file';
   nco{'DATE_CREATION'}.FillValue_ = ncfloat(-fillval);

   nco{'DATE_UPDATE'}.long_name = 'Date of update of single profile file' ;
   nco{'DATE_UPDATE'}.units = 'days since 1950-01-01 00:00:00 UTC';
   nco{'DATE_UPDATE'}.comment = ...
       'Date of update of profile file, not of this aggregation file';
   nco{'DATE_UPDATE'}.FillValue_ = ncfloat(-fillval);

   nco{'INST_REFERENCE'}.long_name = 'Instrument type' ;
   nco{'INST_REFERENCE'}.conventions = 'Brand, type, serial number';
   nco{'INST_REFERENCE'}.FillValue_ = ' ';

   disp('d')

   % Write out the data.

   if getraw
      t(isnan(t)) = fillval;
      nco{'TEMP'}(:) = t(jj,1:ndep);
      nco{'TEMP_QC'}(:) = tqc(jj,1:ndep);
      
      s(isnan(s)) = fillval;
      nco{'PSAL'}(:) = s(jj,1:ndep);
      nco{'PSAL_QC'}(:) = sqc(jj,1:ndep);

      p(isnan(p)) = fillval;
      nco{'PRES'}(:) = p(jj,1:ndep);
      nco{'PRES_QC'}(:) = pqc(jj,1:ndep);
   end

   ta(isnan(ta)) = fillval;
   nco{'TEMP_ADJUSTED'}(:) = ta(jj,1:ndep);
      disp('e')

   nco{'TEMP_ADJUSTED_QC'}(:) = taqc(jj,1:ndep);
   disp('f')
   nco{'TEMP_ADJUSTED_ERROR'}(:) = tae(jj,1:ndep);
   disp('g')

   sa(isnan(sa)) = fillval;
   nco{'PSAL_ADJUSTED'}(:) = sa(jj,1:ndep);
   nco{'PSAL_ADJUSTED_QC'}(:) = saqc(jj,1:ndep);
   nco{'PSAL_ADJUSTED_ERROR'}(:) = sae(jj,1:ndep);

   pa(isnan(pa)) = fillval;
   nco{'PRES_ADJUSTED'}(:) = pa(jj,1:ndep);
   nco{'PRES_ADJUSTED_QC'}(:) = paqc(jj,1:ndep);
   nco{'PRES_ADJUSTED_ERROR'}(:) = pae(jj,1:ndep);

      disp('h')

   lon(isnan(lon)) = fillval;
   nco{'LONGITUDE'}(:) = lon(jj);
   lat(isnan(lat)) = fillval;
   nco{'LATITUDE'}(:) = lat(jj);
   nco{'DATA_CENTRE'}(:) = datacentre(jj,:);
   nco{'DATA_MODE'}(:) = data_mode(jj);
   nco{'DATA_STATE_INDICATOR'}(:) = dsi(jj,:);
   nco{'DATE_CREATION'}(:) = date_cr(jj);
   nco{'DATE_UPDATE'}(:) = date_up(jj);
   nco{'DIRECTION'}(:) = dirn(jj);
   nco{'INST_REFERENCE'}(:) = inst_ref(jj,:);
   nco{'PLATFORM_NUMBER'}(:) = platnum(jj);
   nco{'CYCLE_NUMBER'}(:) = prnum(jj);
   nco{'JULD'}(:) = juld(jj);
   nco{'HANDBOOK_VERSION'}(:) = hbookver(jj,:);

   disp('i')

   % Close file
   nco = close(nco);
   disp([fnm ' successfully written']);
end

return

%-------------------------------------------------------------------------
% Loads in a single Argo profile file into a structure variable. 
%
% Note: sets value=NaN if corresponding QC>=4
%
% INPUTS
%   fname - full path filename for input netcdf file
%
% USAGE: prof = get_prof_nc(fname,getraw);

function prof = get_prof_nc(fname,getraw)

prof = [];

ncload(fname, ...
       'CYCLE_NUMBER', 'LATITUDE', 'LONGITUDE', 'JULD', 'PLATFORM_NUMBER', ...
       'PRES', 'PRES_QC', 'PRES_ADJUSTED', 'PRES_ADJUSTED_QC', ...
       'TEMP', 'TEMP_QC', 'TEMP_ADJUSTED', 'TEMP_ADJUSTED_QC', ...
       'PSAL', 'PSAL_QC', 'PSAL_ADJUSTED', 'PSAL_ADJUSTED_QC', ...
       'PSAL_ADJUSTED_ERROR', 'PRES_ADJUSTED_ERROR', 'TEMP_ADJUSTED_ERROR', ...
       'DATA_MODE', 'DATE_UPDATE', 'DATE_CREATION', 'CALIBRATION_DATE',...
       'DATA_CENTRE','DATA_STATE_INDICATOR','INST_REFERENCE',...
       'DIRECTION','HANDBOOK_VERSION');

if (isempty(LATITUDE) || isempty(PSAL) || ...
    isnan(LATITUDE) || LATITUDE==99999 || isnan(LONGITUDE) || LONGITUDE==99999 ...
    || isnan(JULD) || JULD==99999)
   % No value in this profile
   return
end

%kk = strfind(fname,'_');
%kk = kk(end);
%fnum = str2num(fname(kk+1:kk+3));
%prof.file_number = fnum;

prof.handbookv = HANDBOOK_VERSION;
prof.inst_ref = INST_REFERENCE;
prof.dsi = DATA_STATE_INDICATOR;
prof.dmode = DATA_MODE;
prof.profile_number = CYCLE_NUMBER;

% handle a frequent problem in Argo NetCDF
[r,c]=size(PLATFORM_NUMBER);
if r>c
   PLATFORM_NUMBER=PLATFORM_NUMBER';  % Transpose 
end
tmp = str2num(PLATFORM_NUMBER); 
if length(tmp)~=1
   PLATFORM_NUMBER(PLATFORM_NUMBER<48 | PLATFORM_NUMBER>57) = 32;
   tmp = str2num(PLATFORM_NUMBER); 
   if length(tmp)>1
      tmp = tmp(1);
   end
end
prof.float = tmp;

prof.serial_date = JULD;
prof.lon = getnc(fname,'LONGITUDE');
prof.lat = getnc(fname,'LATITUDE');
% convert longitude to [0,360E]
if prof.lon<0
   prof.lon = rem(prof.lon+360,360);
end

prof.dc = DATA_CENTRE(:)';
prof.dirn = DIRECTION;

d50 = datenum([1950 1 1 0 0 0]);
prof.date_cr = datenum(sscanf(DATE_CREATION,'%04d%02d%02d%02d%02d%02d')') - d50;
prof.date_up = datenum(sscanf(DATE_UPDATE,'%04d%02d%02d%02d%02d%02d')') - d50;

if getraw
   % PRES - this version does NOT sort into ascending order
   if exist('PRES','var') && ~isempty(PSAL)
      PRES(PRES>9999) = nan;
      prof.p = PRES;
      prof.pqc = str2num(PRES_QC);
      prof.p(prof.pqc>=3) = nan;
   end

   % PSAL
   if exist('PSAL','var') && ~isempty(PSAL)
      PSAL(PSAL>9999) = nan;
      prof.s = PSAL;
      prof.sqc = str2num(PSAL_QC);
      if isempty(prof.sqc)
	 prof.sqc = 9*ones(size(prof.s));
      end      
      prof.s(prof.sqc>=3) = nan;
   end

   % TEMP
   if exist('TEMP','var') && ~isempty(TEMP)
      TEMP(TEMP>9999) = nan;
      prof.t = TEMP;
      prof.tqc = str2num(TEMP_QC);
      if isempty(prof.tqc)
	 prof.tqc = 9*ones(size(prof.t));
      end      
      prof.t(prof.tqc>=3) = nan;
   end

   % DOXY
%   if exist('DOXY','var') && ~isempty(DOXY)
%      DOXY(DOXY>9999) = nan;
%      prof.o = DOXY;
%      prof.oqc = str2num(DOXY_QC);
%      if isempty(prof.oqc)
%	 prof.oqc = 9*ones(size(prof.o));
%      end      
%      prof.o(prof.oqc>=3) = nan;
%   end

   % TEMP_DOXY
%   if exist('TEMP_DOXY','var') && ~isempty(TEMP_DOXY)
%      TEMP_DOXY(TEMP_DOXY>9999) = nan;
%      prof.ot = TEMP_DOXY;
%      prof.otqc = str2num(TEMP_DOXY_QC);
%      if isempty(prof.otqc)
%	 prof.otqc = 9*ones(size(prof.ot));
%      end      
%      prof.ot(prof.otqc>=3) = nan;
%   end

    if any([length(prof.p) length(prof.s) length(prof.t) length(prof.pqc) ...
	    length(prof.sqc)] ~= length(prof.tqc))
       prof = [];
       return
    end
end


% ADJUSTED data

% PRES_ADJUSTED - do NOT sort into ascending order
if exist('PRES_ADJUSTED','var') && ~isempty(PRES_ADJUSTED)
   PRES_ADJUSTED(PRES_ADJUSTED>9999) = nan;
   prof.pa = PRES_ADJUSTED;
   prof.paqc = str2num(PRES_ADJUSTED_QC);
   prof.pa(prof.paqc>=3) = nan;
end

% PRES_ERR
if exist('PRES_ADJUSTED_ERROR','var') && ~isempty(PRES_ADJUSTED_ERROR)
   PRES_ADJUSTED(PRES_ADJUSTED>9999) = nan;
   prof.pae = PRES_ADJUSTED_ERROR;
end


% PSAL
if exist('PSAL_ADJUSTED','var') && ~isempty(PSAL_ADJUSTED)
   PSAL_ADJUSTED(PSAL_ADJUSTED>9999) = nan;
   prof.sa = PSAL_ADJUSTED;
   prof.saqc = str2num(PSAL_ADJUSTED_QC);
   if isempty(prof.saqc)
      prof.saqc = 9*ones(size(prof.sa));
   end      
   prof.sa(prof.saqc>=3) = nan;
end

% PSAL_ERR
if exist('PSAL_ADJUSTED_ERROR','var') && ~isempty(PSAL_ADJUSTED_ERROR)
   PSAL_ADJUSTED(PSAL_ADJUSTED>9999) = nan;
   prof.sae = PSAL_ADJUSTED_ERROR;
end

% TEMP
if exist('TEMP_ADJUSTED','var') && ~isempty(TEMP_ADJUSTED)
   TEMP_ADJUSTED(TEMP_ADJUSTED>9999) = nan;
   prof.ta = TEMP_ADJUSTED;
   prof.taqc = str2num(TEMP_ADJUSTED_QC);
   if isempty(prof.taqc)
      prof.taqc = 9*ones(size(prof.ta));
   end      
   prof.ta(prof.taqc>=3) = nan;
end

% TEMP_ERR
if exist('TEMP_ADJUSTED_ERROR','var') && ~isempty(TEMP_ADJUSTED_ERROR)
   TEMP_ADJUSTED(TEMP_ADJUSTED>9999) = nan;
   prof.tae = TEMP_ADJUSTED_ERROR;
end

if any([length(prof.pa) length(prof.sa) length(prof.ta) ...
	length(prof.paqc) length(prof.saqc) length(prof.taqc) ...
	length(prof.pae) length(prof.sae)] ~= length(prof.tae))
   prof = [];
   return
end

% DOXY
%if exist('DOXY_ADJUSTED','var') && ~isempty(DOXY_ADJUSTED)
%   DOXY_ADJUSTED(DOXY_ADJUSTED>9999) = nan;
%   prof.oa = DOXY_ADJUSTED;
%   prof.oaqc = str2num(DOXY_ADJUSTED_QC);
%   if isempty(prof.oaqc)
%      prof.oaqc = 9*ones(size(prof.oa));
%   end      
%   prof.oa(prof.oaqc>=3) = nan;
%end

% TEMP_DOXY
%if exist('TEMP_DOXY_ADJUSTED','var') && ~isempty(TEMP_DOXY_ADJUSTED)
%   TEMP_DOXY_ADJUSTED(TEMP_DOXY_ADJUSTED>9999) = nan;
%   prof.ota = TEMP_DOXY_ADJUSTED;
%   prof.otaqc = str2num(TEMP_DOXY_ADJUSTED_QC);
%   if isempty(prof.otaqc)
%      prof.otaqc = 9*ones(size(prof.ota));
%   end
%   prof.ota(prof.otaqc>=3) = nan;
%end


return

%-----------------------------------------------------------------

