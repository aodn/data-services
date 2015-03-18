function removeoldproduct(newprodfilepath,dest)
            newprod_listing=dir(newprodfilepath);
    newprodfilename=newprod_listing.name;
    [startindex,endindex]=regexp(newprodfilename,'\-\d*\-');  % any number of consecutive numeric digits, bookended by hyphens
     newdatestring=newprodfilename(startindex+1:endindex);  % deployment date
     startindex=regexp(newprodfilename,'WQM');
     newdepthstring=newprodfilename(startindex+4:startindex+5);
     % look for a matching one in dest, that's older
     destfiles=dir(dest);
     lendest=length(destfiles);
     for m=3:lendest        % first 2 of dir are . and ..
         destfilename=destfiles(m).name;
         [deststartindex,destendindex]=regexp(destfilename,'\-\d*\-'); 
         destdatestring=destfilename(deststartindex+1:destendindex);
         deststartindex=regexp(destfilename,'WQM');
         destdepthstring=destfilename(startindex+4:startindex+5);       % 2 digits worth of depth string
         if strcmp(newdatestring,destdatestring) & strcmp(newdepthstring,destdepthstring)

            delete(strcat(dest,'/',destfilename))      % can be absolute or relative path

         end
     end
end
