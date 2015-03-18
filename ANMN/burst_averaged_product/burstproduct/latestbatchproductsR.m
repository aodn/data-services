% ****   run from 10-nsp-mel/home/mbreslin/. Run matlab first, and mylocalpath.m

%comparisondate=datenum([2014 2 15 0 0 0]);
comparisondate=datenum([2013 1 15 0 0 0]);

cd nctoolbox
setup_nctoolbox
% might need to set up path to .m files (/dataproduct/)

cd ~

currentdirlist={'NRS/NRSDAR/Biogeochem_timeseries';'NRS/NRSESP/Biogeochem_timeseries';...
                'NRS/NRSKAI/Biogeochem_timeseries';'NRS/NRSMAI/Biogeochem_timeseries'; ...
                'NRS/NRSNIN/Biogeochem_timeseries';'NRS/NRSNSI/Biogeochem_timeseries'; ...
                'NRS/NRSROT/Biogeochem_timeseries';'NRS/NRSYON/Biogeochem_timeseries'; ...
                'NSW/PH100/Biogeochem_timeseries'; 'NSW/SYD100/Biogeochem_timeseries';...
                'QLD/GBRCCH/Biogeochem_timeseries';'QLD/GBRLSH/Biogeochem_timeseries';...
                'QLD/GBRPPS/Biogeochem_timeseries';'QLD/ITFJBG/Biogeochem_timeseries'};
                                    % (as of Feb 2014)
failedFiles={};
TotalfailedFiles={};
s=0;    % tried file counter
for k=1:length(currentdirlist)
    kdirpath=strcat('../../mnt/opendap/1/IMOS/opendap/ANMN','/',currentdirlist{k});
    remotedirdetails=dir(kdirpath);
      % when the code is healthy, make dest "staging"
%dest=strcat('../imos-t4/IMOS/staging/ANMN/',currentdirlist{k}');

   dest='~/dataproduct';
  
	for i=1 :length(remotedirdetails)
            filename=remotedirdetails(i).name; 
            modification_date=remotedirdetails(i).datenum;
       
           if ~isempty(strfind(filename,'.nc'))
                s=s+1;
                if modification_date>comparisondate            
                        fprintf('A recent file: %s \n',filename)
		    if  ~isempty(strfind(filename,'200804'))&& ~isempty(strfind(filename,'NRSMAI'))
			printf('Excluded NRSMAI 200804. \n')
		    else
                    		try
                            	tempdest='~/testout';
                             	input_filepath=strcat(kdirpath,'/',filename);
                            	fprintf(' Input file:  %s \n',input_filepath)
                            	newprod_filepath = singleWQMburstavproduct(input_filepath,tempdest); % singleWQMburstavproduct creates and moves new prod file to tempdest
                            	fprintf('passed through singleWQMburstavproduct \n')
                            	output_listing=dir(newprod_filepath)
                            	prodfilename=output_listing.name
                            % no call to remove old prod, because we're only processing new files with this version.
                            	[	success0or1,message,messageid]=movefile(newprod_filepath,dest,'f')
                            	fprintf('Output file is %s \n',strcat(dest,'/',prodfilename))
                            	if output_listing.bytes <5000
                                	fprintf('Warning: output file may be empty \n')
                            	end
                            
                    		catch exc
                       			getReport(exc,'extended')
                        		fprintf('Failed. \n')
                        		failedFiles{i}=remotedirdetails(i).name;
                     			continue
		    end
                    end
                end
            end
        end
        if ~isempty(failedFiles)
		TotalfailedFiles= [TotalfailedFiles;failedFiles];
        end
end

if isempty(TotalfailedFiles)
    fprintf('Failed list is empty.\n')
else
    fprintf('List of files causing errors in this directory: \n')
    for i=1:length(TotalfailedFiles)
        fprintf('%s\n',TotalfailedFiles{i})
    end
end
%% ***************************** CTD run  *******************************************
currentdirlist={'NRS/NRSKAI/CTD_timeseries';'SA/SAM8SG/CTD_timeseries';...
                'SA/SAM7DS/CTD_timeseries';'SA/SAM6IS/CTD_timeseries'; ...
                'SA/SAM5CB/CTD_timeseries';'SA/SAM4CY/CTD_timeseries'; ...
                'SA/SAM3MS/CTD_timeseries';'SA/SAM1DS/CTD_timeseries'; ...
                'SA/SAM2CP/CTD_timeseries'};
                                    % Directories containing CTD's (as of Feb 2014)
                                    failedFiles={};
TotalfailedFiles={};
s=0;    % tried file counter
for k=1:length(currentdirlist)
    % cd(currentdirlist{k})
   kdirpath=strcat('../../mnt/opendap/1/IMOS/opendap/ANMN','/',currentdirlist{k});

    remotedirdetails=dir(kdirpath);

    %dest=strcat('../imos-t4/IMOS/staging/ANMN/',currentdirlist{k});
dest=('~/dataproduct')
         for i=1:length(remotedirdetails)
            filename=remotedirdetails(i).name; 
            modification_date=remotedirdetails(i).datenum;
       
           if ~isempty(strfind(filename,'.nc'))
                s=s+1;
                if modification_date>datenum([2013 1 1 1 1 1])
                            fprintf('A recent file: %s',filename)
                    try
                            tempdest='~/testout';
                            input_filepath=strcat(kdirpath,'/',filename)
                            fprintf(' Input filepath is:  %s \n',input_filepath)
                           
                            newprod_filepath = singleCTDburstavproduct(input_filepath,tempdest); 
                            fprintf('passed through singleCTDburstavproduct \n')
                            output_listing=dir(newprod_filepath);
                            prodfilename=output_listing.name;
                            removeoldproduct(newprod_filepath,dest)
                            % removed a call to remove old prod, because we're not producing duplicates.
                            [success0or1,message,messageid]=movefile(newprod_filepath,dest,'f')
                            fprintf('Output file is %s \n',strcat(dest,'/',prodfilename))
                            if output_listing.bytes <5000
                                fprintf('Warning: output file may be empty \n')
                            end
                            
                    catch exc
                        getReport(exc,'extended')
                        fprintf('Failed. \n')
                        failedFiles{i}=remotedirdetails(i).name;
                     continue
                    end
                end
            end
        end
        if ~isempty(failedFiles)
            TotalfailedFiles= [TotalfailedFiles;failedFiles];

        end
end
 


