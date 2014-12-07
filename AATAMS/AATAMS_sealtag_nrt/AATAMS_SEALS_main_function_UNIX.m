%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%ACCESS the log files of the files already processed by MATLAB
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fileinput1 = '/usr/local/emii/data/matlab/AATAMS/AATAMS_TAGS_LOGS_matlab_processing.txt';
%
fid = fopen(fileinput1,'r');
line=fgetl(fid);
inputprocessed{1} = line ;
i=2;
while line~=-1,
  line=fgetl(fid);
  inputprocessed{i} = line ;
  i=i+1;
end
nbinputprocessed = length(inputprocessed)-1;
fclose(fid)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Listing of all the input files available in the input directory
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
dirinput = '/usr/local/emii/data/ftp-landing/smru/matlab/';
listfiles = dir(strcat(dirinput,'*.dat'));
%
nbinputfiles= length(listfiles);
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Creation of the list of files to process
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
k=1;
test_verif = 0;
for i = 1:nbinputfiles
    if (nbinputprocessed)
        for j = 1:nbinputprocessed
            if (listfiles(i).name == inputprocessed{j})
                test_verif = test_verif +1;
            end
        end
        if (~test_verif)
            files2process{k} = listfiles(i).name;
            k=k+1;
        end
        test_verif = 0;
    else
        files2process{k} = listfiles(i).name;
        k=k+1;
        test_verif = 0;
    end
end
%
nbfiles2process = 0;
try
nbfiles2process = length(files2process);
end
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%to process each file we call another matlab function
%(read_seal_tagging_profile_v1.m)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if (nbfiles2process)
fid_w = fopen(fileinput1,'a');
for zz =1:nbfiles2process
    fileinput2 = strcat(dirinput,files2process{zz});
    AATAMS_SEALS_subfunction1_UNIX(fileinput2)
    fprintf(fid_w,'%s\r\n',files2process{zz});
end
fclose(fid_w)
end
quit
