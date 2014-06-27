DATA_FOLDER='/media/Laurent_emII/df_root/IMOS/opendap/FAIMMS';
[~,~,ncFileList]=DIRR(strcat(DATA_FOLDER,filesep,'*.nc'),'name');
ncFileList=ncFileList';

nNCFILE=length(ncFileList);
long_name=[];
units=[];
standardName=[];

err_long_name=[];
err_standardName=[];

for iiFile=1:nNCFILE
    clear allVarInfo
    try
        nc=netcdf.open(ncFileList{iiFile},'NC_NOWRITE');
        [allVarInfo]=getVarInfo(nc);
        if sum(strcmp(' status_flag',{allVarInfo.standard_name}))~=0
            errlong_name=allVarInfo(strcmp(' status_flag',{allVarInfo.standard_name})).long_name;
            errstandardName=allVarInfo(strcmp(' status_flag',{allVarInfo.standard_name})).standard_name;
            
            err_long_name=[err_long_name errlong_name];
            err_standardName=[err_standardName errstandardName];

        end
        standardName=[standardName {allVarInfo.standard_name}];
        units=[units {allVarInfo.units}];
        long_name=[long_name {allVarInfo.long_name}];
        netcdf.close(nc)
    catch err1
         warning('MATLAB:getAllUniqueVariables:ncFile', strcat(char(ncFileList{iiFile}), 'Not valid NetCDF'));

        try
         netcdf.close(nc)
        catch err2
            warning('MATLAB:getAllUniqueVariables:ncid', 'Not valid netcdf identifier');
        end 
    end
end

[errSTANDARD_NAME,irr]=unique_no_sort(err_standardName);
errLONG_NAME=(err_long_name(irr));


[STANDARD_NAME,i,j]=unique_no_sort(standardName);
UNITS=(units(i));
LONG_NAME=(long_name(i));

[LONG_NAME,i,j]=unique_no_sort(long_name);
UNITS=(units(i));
STANDARD_NAME=(standardName(i));


STANDARD_NAME'
UNITS'
LONG_NAME
