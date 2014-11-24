function [output,varargout] = scan_filename(fname,variable) 
% THIS ROUTINE READS NOMINAL DEPTH IN FILENAMES 
% INPUT : fname : structure of file name 
%          variable : option are :
%                 - 'deployment' :extracts deployments info,ie node,site,
%                 deployment id
%                 - 'nomdepth'  : lists nominal depths
%                 - 'inst_name' : lists  instruments

% OUTPUT: nomdepth :vector of nominal depth

% July2014: change routine to account for all new instrument types( 6more
%type in latest uploaded deployments)
% November 2014: add case deployment to get deployment file info
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
switch variable
    case 'deployment'
          for nf = 1:length(fname)

            dash = regexp(fname(nf).name,'-');
            uscore = regexp(fname(nf).name,'_');
            output(nf).name = fname(nf).name;
            output(nf).node = fname(nf).name(dash(1)+1:uscore(2)-1);
            output(nf).site = fname(nf).name(uscore(4)+1:uscore(5)-1);
            output(nf).deploymt = fname(nf).name(dash(2)+1:dash(3)-1);
            output(nf).id = strcat(output(nf).site,'-',output(nf).deploymt);
% GET RID OF POTENTIAL SPACE,TRAILING BLANK WORDS
            output(nf).deploymt= deblank(output(nf).deploymt); 
           output(nf).node(isspace(output(nf).node)) = []; 
           output(nf).site(isspace(output(nf).site)) = [];       

          end
	case 'nomdepth'
        
		for nf = 1:length(fname)
           
			dash = regexp(fname(nf).name,'-');	
			uscorend = regexp(fname(nf).name,'_END') ;
			nomdepth(nf) = str2num(fname(nf).name(dash(end-2)+1: uscorend -1));
            
        end
     output = nomdepth;
     
	case 'inst_name'
		for nf = 1:length(fname)

			dash = regexp(fname(nf).name,'-');
			dstart = dash(3) + 1;
			dend = dash(end-2)- 1;
			instname{nf} = fname(nf).name(dstart:dend);		
		end
		[output,varargout{1},ic] = unique(instname);
end