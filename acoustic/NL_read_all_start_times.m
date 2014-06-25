function NL_read_all_start_times(deployment_number)
% Reads start times of recordings from all sea noise data files in the
% current directory and save those with the filenames in a MAT-file 
% Start times are stored in date number since 1/01/0001 00:00:00 

% Rev. 2 (Sep 2012): Manual specification of common output file names  
% containing the deployment number instead of automatic naming using folder 
% names  

tic;

narginchk(0,1);

w = pwd;

if isempty(deployment_number)
    deployment_number = input('Please type 4-digit deployment number: ');
end
outputFile = ['t', num2str(deployment_number), '_start_times']; 

try
    filelist = dir('*.DAT');
    
    % we get rid of possible empty files
    iEmptyFiles = [filelist.bytes] == 0;
    filelist(iEmptyFiles) = [];
    
    Nfiles = length(filelist);
    
    Start_times.time        = NaN(Nfiles, 1);
    Start_times.file_name   = cell(Nfiles, 1);
    
    for nf = 1:Nfiles
        Start_times.time(nf)      = NL_read_rec_start_time(filelist(nf).name);
        Start_times.file_name{nf} = filelist(nf).name(1:end-4);
    end
    
    % keep only files with a start time of recordings information
    iFileWithStartTime      = ~isnan(Start_times.time);
    Start_times.time        = Start_times.time(iFileWithStartTime);
    Start_times.file_name   = Start_times.file_name(iFileWithStartTime);
    
    % Sort data files according to recording time:
    [Start_times.time, ntsort] = sort(Start_times.time);
    Start_times.file_name = Start_times.file_name(ntsort);
    
    save(outputFile, 'Start_times');
catch e
    fprintf('%s\n',   ['Error : NL_read_all_start_times failed on ' w]);
    errorString = getErrorString(e);
    fprintf('%s\n',   ['Error says : ' errorString]);
end

fprintf(' %-30s ..... ','NL_read_all_start_times');
fprintf('%3.3f %s\n',toc,'sec')
