function ResultTableSal=maisSalinity(input_filename,inputsal,inputtime,instrument_depth,flags);

% Inputs:
% input_filename   - string containing file name to check for files in intervention list 
% inputsal	   - salinity array
% inputtime	   - time array
% instrument_depth - depth as recorded in global attribute instrument_nominal_depth
% flags		   - salinity QC flags from FV01
%
% Outputs:
% ResultTableSal   - a 1 x 5 array containing [aggregatedT aggregatedSal numIncludedSal SDBurstSal rangeBurstSal] 
%
% Remove salinity data that is flagged as 99.9 perc Roc - within mode:
% take the RoC alerted points and toolbox flags as exclusions when
% calling aggregate.m.
% RoC algorithm lookup tables are available for combinations of 3 attributes: depth,variable,
% mode. indexattrib1 = depth, etc. The lookup tables are in a mat file called RoC_Cutoffs_HistSD.mat,
% and the relevant row in the lookup table is chosen by an index that is a function of the
% particular combination of the 3 attributes.

   %% ------------ prelims for RoC ------------------
    % ----------- For MaIs RoC table selection: ----------------------
    % 3 attributes - Depth (20m / 90m), variable (temp / sal), mode (between burst / within burst)
    % To reference the RoC table for one of these combinations, use the index
    % of each of the attributes in zero-base, eg. lookup indices
    % for 20m salinity between mode is: attribindices=[0 1 0]

% Note: A table showing explicity which combination matches with which row is in 
% orderoflookup (in the mat file), so a user can ignore the formulae
    
    possible_depths=[20 90];    num_attrib1=length(possible_depths);
    possible_variables={'temperature' 'salinity'};  num_attrib2=length(possible_variables);
    possible_modes={'between' 'within'};        num_attrib3=length(possible_modes);
    % -----------------------------------------------------------
    
   
    depth_diff=abs(possible_depths-instrument_depth); [y, index]=min(depth_diff);
    depth=possible_depths(index);           % assign a depth from either 20m or 90m
    indexattrib1=index-1;                         % the index into possible_depths, zero-base

% The function to generate the index for the lookup table is lookupindex=indexattrib1*num_attrib3*num_attrib2+indexattrib2*num_attrib3+indexattrib3;
% where "num_attribx" is the number of possibilities for that attribute. In
% this case, it happens to be 2 for every attribute. Inddexattribx is in
% zero-base (ie. start count from 0) - so 0 or 1.
indexattrib2 = 1;       	% Salinity
% Calculate lookup index for Roc tables for within mode
indexattrib3=1;             	% Within mode
% attribute indices are [indexattrib1 indexattrib2 indexattrib3];
lookupindex=indexattrib1*num_attrib3*num_attrib2+indexattrib2*num_attrib3+indexattrib3;
% ie. lookupindex=indexattrib1*2*2 + indexattrib2*2 + indexattrib3;
% Above formula gives index in zero-base, so array index will be:
lookupindex=lookupindex+1;
load('RoC_Cutoffs_HistSD.mat')			% contains Cutoff999MaIs, HistSDMaIs, and orderoflookup
% Contents of RoC_Cutoffs_HistSD.mat:
%
% Cutoff999MaIs - 8 x 1 array of cutoffs for the 99.9th perc of historical values of 
% normalised RoC values. Depends on the 3 attributes each with 2 possible vals: hence 2^3 rows
% HistSDMaIs   -  8 x 12 array or historical values for SD, also dependent on the 3 attributes,
% 		  plus time of year
SDlookupwithin=HistSDMaIs(lookupindex,:);       % the relevant 1 x 12 array of SDs
monthlookup=[1 2 3 4 5 6 7 8 9 10 11 12];
meantime=mean(inputtime(isfinite(inputtime))); datevecs=datevec(meantime);
monthofdata=datevecs(2);            		% take the average month
SDhistwithin=interp1(monthlookup,SDlookupwithin,monthofdata);
cutoffwithin=Cutoff999MaIs(lookupindex);        % variable from Roc_Cutoffs_HistSD.mat

% for between, indexattrib3=0;
indexattrib3=0;
lookupindex=indexattrib1*num_attrib3*num_attrib2+indexattrib2*num_attrib3+indexattrib3;
lookupindex=lookupindex+1;
SDlookupbetween=HistSDMaIs(lookupindex,:);          % the relevant 1 x 12 array of SDs
monthlookup=[1 2 3 4 5 6 7 8 9 10 11 12];
SDhistbetween=interp1(monthlookup,SDlookupbetween,monthofdata);
cutoffbetween=Cutoff999MaIs(lookupindex);

difft=round(86400*diff(inputtime));   % now in seconds, easier for debugging
inburstint=mode(difft);                     % commonly 1 sec 
indexnotmode=logical(difft~=inburstint & difft>3*inburstint);
betburstint=mode(difft(indexnotmode));
allowed_multiple=15;                        % a multiple of inburstint
% Decision making for identifying bursts: 
% If the time-gap between two points is less than 15 times the normal "within burst" gap,
% then the points are neighbours within a burst.
% This configuration works for all MaIs data files 2008 to 2013. If you set the 
% allowed gap to be too narrow, some situations where the sensor failed for part of a burst
% are mis-identified.
% Note that this value of 15 times normal breaks down for a small number of non-MaIs files
% (eg. GBRPPS) where the normal within gap is 10sec, and normal between gap is 40 sec  
%
% Any 'isolated' points, not 'close' to a neighbour on either side, are assigned NaN
n=length(inputsal);
difftol=0.01;
allowed_gap=allowed_multiple*inburstint+difftol;  
diffx=diff(inputsal);
hasrightneighbour=find(difft<=allowed_gap);
hasleftneighbour=hasrightneighbour+1;       % If a point has a right neighbour,
                                            % then that right neighbour has a
                                            % left neighbour
indexinternals=intersect(hasrightneighbour,hasleftneighbour);
indexinternals=indexinternals(find(indexinternals<length(difft)));
leftedgepts=setdiff(hasrightneighbour,indexinternals);   % these points have only a right neighbour
rightedgepts=setdiff(hasleftneighbour,indexinternals);     % these points have only a left neighbour
% Note, these are all indices into t and x
startburstind=leftedgepts;      finishburstind=rightedgepts;    
aggregatedx=zeros(length(startburstind),1);
aggregatedt=zeros(length(startburstind),1);
% at least this loop is only the length of num of bursts, not length
% of data array
for i=1:length(startburstind)
   aggregatedx(i)=mean(inputsal(startburstind(i):finishburstind(i)));
   aggregatedt(i)=median(inputtime(startburstind(i):finishburstind(i)));
end

Rocvalswithin=nan(1,n);
Rocvalswithin(indexinternals)=abs(diffx(indexinternals))+ abs(diffx(indexinternals-1));
                     
                            % but don't overwrite internals:
Rocvalswithin(leftedgepts)=2*abs(diffx(leftedgepts));
Rocvalswithin(rightedgepts)=2*abs(diffx(rightedgepts-1));

% Rocwithin is now complete, apart from any data points that are
% isolated. The rate of change across the gaps between bursts are 
% ignored: at edges of bursts, rate of change is based only on 
% the close neighbour
 
NormRocvalswithin=Rocvalswithin/SDhistwithin;

h=length(aggregatedx);
testvals=nan(1,h); 
diffx=diff(aggregatedx);
difft=diff(aggregatedt);
Rocvalsbetween(1)=nan;
Rocvalsbetween(2:h-1)=abs(diffx(2:end))+ abs(diffx(1:end-1));
Rocvalsbetween(2:h-1)=abs(diffx(2:end))+ abs(diffx(1:end-1));
Rocvalsbetween(h)=nan;

NormRocvalsbetween=Rocvalsbetween/SDhistbetween;

withinalertindices=find(NormRocvalswithin>cutoffwithin);
nanwithinindices=find(isnan(NormRocvalswithin));
withinalertarray=zeros(size(inputsal));
withinalertarray(withinalertindices)=1;  withinalertarray(nanwithinindices)=NaN;
betweenalertarray=zeros(size(aggregatedx));
betweenalertindices=find(NormRocvalsbetween>cutoffbetween);
nanbetweenindices=find(isnan(NormRocvalsbetween));
betweenalertarray(betweenalertindices)=1; betweenalertarray(nanbetweenindices)=NaN;


% For the points on each two ends of each burst, assign the percResult from
% percResultBetween, to address the case of a burst full of zeros (or other
% equal data value)

 withinalertarray(leftedgepts(2:end))=max(withinalertarray(leftedgepts(2:end)),betweenalertarray(2:end));
 withinalertarray(rightedgepts(1:end-1))=max(withinalertarray(rightedgepts(1:end-1)),betweenalertarray(2:end));
 
 alertindices=find(withinalertarray>0 | isnan(withinalertarray));
 nanalertindices=find(isnan(withinalertarray));
 
% --------------
% alertindices are the indices of points with Roc > cutoffwithin, or
% cutoffbetween at edge of bursts, or Roc = NaN
% nanalertindices are the indices of points with Roc=NaN

highflags=find(flags>=3);       % exclude flags of 3, which are mostly RoC flags. Flag 4 includes out-of-water
highflagpercentage=length(highflags)/length(flags);
fprintf('Percentage of flag 3 and 4 in data: %3.0  \n',highflagpercentage)

PSALexclusions=union(alertindices,highflags);

[aggregatedT,aggregatedSal,numIncludedSal,SDBurstSal,rangeBurstSal]=aggregate(inputtime,inputsal,60,PSALexclusions);
psalemptyburst=~isempty(find(numIncludedSal==0));

vectimes=datevec(aggregatedT);vectimes(:,6)=round(vectimes(:,6)); aggregatedT=datenum(vectimes);

ResultTableSal=[aggregatedT aggregatedSal numIncludedSal SDBurstSal rangeBurstSal];
FillValue=999999;
ResultTableSal(find(isnan(ResultTableSal)))=FillValue;

% ----------- manual visualising block: comment/uncomment (ctrl-R, ctrl-T) ------------------- 
%         figure
%         plot(aggregatedT,aggregatedSal)
%         datetickzoom
%         hold
%         plot(aggregatedT,aggregatedSal,'.')
%         title('Aggregated data')
%         disp('to return to script, use command return')
%         suggest check for any obvious spike in aggregatedSal, and excise
%         manually: eg. g=find(aggregatedSal<35); aggregatedSal(g)=nan;
%         Because if run the Stage 4 algorithm, this removes av for whole
%         burst and it's 2 neighbours - and if there are a couple of
%         problems, can have a gap in the data of an hour or more
%         
%         keyboard
%         ResultTableSal(:,2)=aggregatedSal;      % save any keyboard changes
%         ResultTableSal(find(isnan(ResultTableSal)))=FillValue;
% ---------- end manual block -----------------

% 1. IMOS_ANMN-NRS_CKOSTUZ_20081209T021100Z_NRSMAI-SubSurface_FV01_NRSMAI-SubSurface-081209-WQM-90_END-20090405T102700Z_C-20130920T080859Z.nc
% 2. IMOS_ANMN-NRS_CKOSTUZ_20081209T021100Z_NRSMAI-SubSurface_FV01_NRSMAI-SubSurface-081209-WQM-20_END-20090405T102700Z_C-20130715T061246Z.nc
% 3. IMOS_ANMN-NRS_KOSTUZ_20090910T231400Z_NRSMAI-SubSurface_FV01_NRSMAI-SubSurface-090910-WQM-20_END-20091210T222900Z_C-20130715T061451Z.nc
% 4. IMOS_ANMN-NRS_KOSTUZ_20091211T002900Z_NRSMAI-SubSurface_FV01_NRSMAI-SubSurface-091211-WQM-20_END-20100512T215823Z_C-20131004T055656Z.nc
% 5. IMOS_ANMN-NRS_KOSTUZ_20100513T031313Z_NRSMAI-SubSurface_FV01_NRSMAI-SubSurface-100513-WQM-20_END-20101026T214900Z_C-20130715T061604Z.nc
% 6. IMOS_ANMN-NRS_CKOSTUZ_20080828T000500Z_NRSMAI-SubSurface_FV01_NRSMAI-SubSurface-080828-WQM-20_END-20081209T015000Z_C-20130715T061330Z.nc
intervenefile1='081209-WQM-90'; intervenefile2='081209-WQM-20'; intervenefile3='090910-WQM-20';
intervenefile4='091211-WQM-20'; intervenefile5='100513-WQM-20'; intervenefile6='080828-WQM-20';
if ~isempty(strfind(input_filename,intervenefile1))| ~isempty(strfind(input_filename,intervenefile2))
    g=find(aggregatedSal<35);aggregatedSal(g)=nan;
elseif ~isempty(strfind(input_filename,intervenefile3))
     g=find(aggregatedSal<34.5);aggregatedSal(g)=nan;
elseif ~isempty(strfind(input_filename,intervenefile4))
    timevecs=datevec(aggregatedT);ap=find(timevecs(:,2)==4);
    g=find(aggregatedSal<35.2);h=intersect(ap,g);aggregatedSal(h)=nan;
elseif ~isempty(strfind(input_filename,intervenefile5))
    timevecs=datevec(aggregatedT);ap=find(timevecs(:,2)==9);
    g=find(aggregatedSal<35);h=intersect(ap,g);aggregatedSal(h)=nan;
elseif ~isempty(strfind(input_filename,intervenefile6))
    g=find(aggregatedSal<35);aggregatedSal(g)=nan;
end


end
