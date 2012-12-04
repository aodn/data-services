function NL_read_all_start_times
% Reads start times of recordings from all sea noise data files in the
% current directory and save those with the filenames in a MAT-file 
% Start times are stored in date number since 1/01/0001 00:00:00 

% Rev. 2 (Sep 2012): Manual specification of common output file names  
% containing the deployment number instead of automatic naming using folder 
% names  

w = pwd;
s1 = input('Please type 4-digit deployment number: ');
s1 = ['t',num2str(s1)]; 

filelist = dir('*.dat');
Nfiles = length(filelist);
Start_times.time = zeros(Nfiles,1);
Start_times.file_name = repmat('00000000',Nfiles,1);
npf = 1;
for nf = 1:Nfiles
    if filelist(nf).bytes ~= 0
        Date  = NL_read_rec_start_time(filelist(nf).name);
        if ~isempty(Date)
            Start_times.time(npf) = Date;
            Start_times.file_name(npf,:) = filelist(nf).name(1:end-4);
            npf = npf + 1;
        end
    end
end
N = find(Start_times.time > 0);
Start_times.time = Start_times.time(N);
Start_times.file_name = Start_times.file_name(N,:);
% Sort data files according to recording time:
[t,ntsort] = sort(Start_times.time);
file_names = Start_times.file_name(ntsort,:);
No_fails = find(t > 0);
Start_times.time = t(No_fails);
Start_times.file_name = file_names(No_fails,:);

s = ['save ',s1,'_start_times Start_times'];
eval(s)


