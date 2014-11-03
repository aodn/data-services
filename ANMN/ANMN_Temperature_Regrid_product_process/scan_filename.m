function [output,varargout] = scan_filename(fname,variable) 
% this routine reads nominal depth in filenames 
% INPUT : fname : structure of file name 
%         variable : output required :either 'nomdepth' for list of nominal 
%                    depths or 'inst_name' for list of instruments

% OUTPUT: nomdepth :vector of nominal depth
%July2014: change routine to account for all new instrument types( 6more
%type in latest uploaded deployments)

switch variable
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
	
	
