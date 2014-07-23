function filenameTest(start_times_file_name, number_days, Rec_period)
% Just testing the filename-handling logic of filenameTest 


tic;

narginchk(0,6);

w = pwd;

try
   
    if isempty(start_times_file_name)
        start_times_file_name = uigetfile('*.mat', 'Open mat-file with recording start times');
    end
    load (start_times_file_name);
    
    N_start_rec = 1;
    
    if isempty(number_days)
        disp(' ')
        number_days = input('Specify number of days with calculated PSD to store in each output mat-file (default 5): ');
        if isempty(number_days)
            number_days = 5;
        end
    end
    
    if isempty(Rec_period)
        disp(' ')
        Rec_period = input('Specify programmed repetition period of recordins in seconds (900 s for IMOS) ');
        if isempty(Rec_period)
            Rec_period = 900;
        end
    end
    
    t = Start_times.time;
    t0 = t(N_start_rec);
    t = t(N_start_rec:end) - t0;
    file_names = Start_times.file_name(N_start_rec:end);
    
    Nfiles = length(t);
    Nrec = ceil(number_days/Rec_period*3600*24); % number of recordings processed in each output file
    Nmatfiles = ceil(length(t)/Nrec); % number of output mat files
    fprintf('Nfiles = %d\nNrec = %d\nNmatfiles = %d\n', Nfiles, Nrec, Nmatfiles);
    
    %%% snip

    File_name       = char(zeros(Nfiles, 8));
    Start_time_day  = zeros(1, Nfiles);
    
    %%% snip
    
    for nmf = 1:Nmatfiles
        if nmf < Nmatfiles
            ndf = (Nrec*(nmf-1)+1 : Nrec*nmf);
        else
            ndf = (Nrec*(nmf-1)+1 : length(t));
        end
        NDF = length(ndf);
        fprintf('\nnmf = %d  (NDF=%d)\n', nmf, NDF);
        
        Frame_time = NaN*zeros(1, NDF);
        for nf = 1:NDF
            try
                filename = [file_names{ndf(nf),:}, '.DAT'];
                
                %%% snip

                % Original code:
                % File_name(NDF*(nmf-1) + nf, :) = filename(1:end-4);
                % Start_time_day(NDF*(nmf-1) + nf) = Start_times.time(NDF*(nmf-1) + nf);              
                
                File_name(ndf(nf), :) = filename(1:end-4);
                Start_time_day(ndf(nf)) = Start_times.time(ndf(nf));              
                
                %%% snip

            catch e
                fprintf('%s\n',   ['Error : filenameTest failed on processing ' filename]);
                errorString = getErrorString(e);
                fprintf('%s\n',   ['Error says : ' errorString]);
            end
        end
        % Save output file:
        %%% snip
        
    end
    clear Freq
    close all
    % save long-term average spectrogram for entire deployment to display at eMII data portal:
    matfname = [start_times_file_name(1:5), '_longterm_spectrogram'];
    save(matfname, 'File_name', 'Start_time_day');
    clear File_name Start_time_day
                
    %%% snip

catch e
    fprintf('%s\n',   ['Error : filenameTest failed on preparing ' w]);
    errorString = getErrorString(e);
    fprintf('%s\n',   ['Error says : ' errorString]);
end

fprintf(' %-30s ..... ','filenameTest');
fprintf('%3.3f %s\n',toc,'sec')
