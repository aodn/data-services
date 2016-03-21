#!/bin/bash
# series of functions to retrieve information from NetCDF files
# set attributes, find min max of variables ...
# recommendations

# check if variable exist in netcdf file
# $1 - netcdf file
# $2 - variable
nc_has_variable() {
    local nc_file=$1; shift
    local var=$1; shift
    ncks -m -v "$var" $nc_file &>/dev/null
}
export -f nc_has_variable

# list all variables in netcdf file (each per line)
# $1 - netcdf file
nc_list_variables() {
    local nc_file=$1; shift
    ncks -m $nc_file 2>/dev/null | grep -e "^[^ ]\+:" | cut -d: -f1
}
export -f nc_list_variables

# check if variable attribute exist in netcdf file
# $1 - netcdf file
# $2 - variable
# $3 - attribute name
nc_has_variable_att() {
    local nc_file=$1; shift
    local var=$1; shift
    local attribute=$1; shift

    ncks -m -v $var $nc_file | grep -q $attribute
}
export -f nc_has_variable_att

# returns variable attribute from netcdf file
# $1 - netcdf file
# $2 - variable
# $3 - attribute name
nc_get_variable_att() {
    local nc_file=$1; shift
    local var=$1; shift
    local attribute="$1"; shift

    if nc_has_variable_att $nc_file $var "$attribute"; then
        ncks -m -v $var $nc_file | grep $attribute | head -1 | grep  -o  'value = .*$' | sed -e 's#^value = ##g'
    fi
}
export -f nc_get_variable_att

# get variable values of netcdf and removes _FillValue
# $1 - netcdf file
# $2 - variable
nc_get_variable_values() {
    local nc_file=$1; shift
    local var=$1; shift
    local fillvalue=_FillValue
    local fillvalue_value
    local var_values

    if nc_has_variable $nc_file $var; then
        var_values=`ncks -s "%f\n" -H -C -v $var $nc_file | tr -s "[:space:]" "\n"`

        if nc_has_variable_att $nc_file $var $fillvalue; then
            fillvalue_value=`nc_get_variable_att $nc_file $var $fillvalue`
            echo $var_values | sed 's/$fillvalue_value//g' |  sed 's/\s/\n/g' # remove var values containing fillvalue
        else
            echo $var_values
        fi

    fi
}
export -f nc_get_variable_values

# return min of variable
# $1 - netcdf file
# $2 - variable
nc_get_variable_min() {
    local nc_file=$1; shift
    local var=$1; shift
    _nc_get_variable_min_max $nc_file $var | cut -d' ' -f1
}
export -f nc_get_variable_min

# return max of variable
# $1 - netcdf file
# $2 - variable
nc_get_variable_max() {
    local nc_file=$1; shift
    local var=$1; shift
    _nc_get_variable_min_max $nc_file $var | cut -d' ' -f2
}
export -f nc_get_variable_max

# return min string value of time (to use for time extent gatt)
# WARNING - assumes that time values are sorted
# $1 - netcdf file
nc_get_time_min() {
    local nc_file=$1; shift
    local time_data=`_nc_get_time_values $nc_file`

    if _nc_check_time_string_valid $nc_file; then
        local time_str=`echo $time_data | cut -d',' -f1 | sed -e "s/\"//g"`
        _nc_transform_time_str "$time_str"
    fi
}
export -f nc_get_time_min

# return max string value of time (to use for time extent gatt)
# WARNING - assumes that time values are sorted
# $1 - netcdf file
nc_get_time_max() {
    local nc_file=$1; shift
    local time_data=`_nc_get_time_values $nc_file`

    if _nc_check_time_string_valid $nc_file; then
        local time_str=`echo $time_data | rev | cut -d',' -f1 | rev | sed -e "s/\"//g"`
        _nc_transform_time_str "$time_str"
    fi
}
export -f nc_get_time_max

# "$@" - parameters for ncatted
nc_set_att() {
    ncatted "$@"
}
export -f nc_set_att

# delete ALL empty attributes from netcdf file
# $1 - netcdf_file
nc_del_empty_att() {
    local nc_file=$1; shift
    _nc_del_empty_varatt $nc_file
    _nc_del_empty_gatt $nc_file
}
export -f nc_del_empty_att

# return boolean gatt exists in NetCDF
# $1 - netcdf file
# $2 - global attribute name
nc_has_gatt() {
    local nc_file=$1; shift
    local gattname="$1"; shift
    local -i line_number_all_gatt=`_nc_get_gatt_line_from_ncdump $nc_file`
    local att_list="$(ncdump -h $nc_file | sed -n "${line_number_all_gatt},\$p" | grep -o  ":.* = "   | cut -d'=' -f1 |sed 's#:##g')"

    echo $att_list | grep -w  -q  $gattname
}
export -f nc_has_gatt

# return global attribute value
# $1 - netcdf file
# $2 - global attribute name
nc_get_gatt_value() {
    local nc_file=$1; shift
    local gattname=$1; shift
    local attval
    local -i line_number_all_gatt=`_nc_get_gatt_line_from_ncdump $nc_file`

    if nc_has_gatt $nc_file $gattname; then
        # get line of attribute
        local -i line_number_gatt="$(ncdump -h $nc_file | cat -n | sed -n "${line_number_all_gatt},\$p" | grep ":${gattname} = " | awk {'print $1'})"

        # cant be integer in case empty
        local line_number_next_gatt="$(ncdump -h $nc_file | cat -n | sed -n "$(( ${line_number_gatt} +1 )),\$p" | grep ":.* = " | head -1 | awk {'print $1'})"

        # conditions in case we gotta retrieve last attribute of the gatt list
        if [[ ! -z $line_number_next_gatt ]]; then
            # get everything in between the two attributes
            attval="$(ncdump -h $nc_file | sed -n "${line_number_gatt},$(( $line_number_next_gatt - 1))p" | sed "s|:${gattname} = \"||g" | sed 's|\" ;$||g' | sed -e 's/^[ \t]*//' )"
        else
            # if last global attribute of the list
            attval="$(ncdump -h $nc_file | sed -n "${line_number_gatt},\$p" | head -n -1 | sed "s|:${gattname} = \"||g" | sed 's|\" ;$||g' | sed -e 's/^[ \t]*//' )"
        fi
    fi
    echo $attval
}
export -f nc_get_gatt_value

# return type of function, float, int, double, byte
# $1 - netcdf file
# $2 - variable
nc_get_variable_type() {
    local nc_file=$1; shift
    local var=$1; shift
    local var_type
    if nc_has_variable $nc_file $var; then
        # extract the ncdump type of a variable, float, double, byte, short, long, char . Line example '   double TIME(INSTANCE) ;"
        var_type="$(ncdump -h $nc_file  | grep -e "^.*$var(.*) ;$" | awk '{print $1;}')"

        if [ "$var_type" == "float" ]; then
            var_type=f
        elif [ "$var_type" == "double" ]; then
            var_type=d
        elif [ "$var_type" == "byte" ]; then
            var_type=b
        elif [ "$var_type" == "short" ]; then
            var_type=s
        elif [ "$var_type" == "long" ]; then
            var_type=l
        elif [ "$var_type" == "char" ]; then
            var_type=c
        else
            return 1
        fi
        echo $var_type
    else
        return 1
    fi
}
export -f nc_get_variable_type

#####################
# PRIVATE FUNCTIONS #
#####################

# return min max of variable, comma separated
# $1 - netcdf file
# $2 - variable
_nc_get_variable_min_max() {
    local nc_file=$1; shift
    local var=$1; shift

    nc_get_variable_values $nc_file $var | awk '{if(min==""){min=max=$1}; if($1>max) {max=$1}; if($1<min) {min=$1}; total+=$1; count+=1} END {print  min, max}'
}
export -f _nc_get_variable_min_max

# delete empty global attributes
# $1 - netcdf file
_nc_del_empty_gatt() {
    local nc_file=$1; shift
    local line_number=`_nc_get_gatt_line_from_ncdump $nc_file`
    local att_list="$(ncdump -h $nc_file | sed -n "${line_number},\$p" | grep  '= "" ;$' | cut -d':' -f2 | cut -d'=' -f1  | sed -e 's/\t//g'  | sed -e '/^$/d' | tr '\n' ' ')"
    local att

    if [[ ! -z $att_list ]]; then
        for att in $att_list; do
            nc_set_att -a $att,global,d,c, $nc_file
        done
    fi
}
export -f _nc_del_empty_gatt

# delete empty variable attributes from netcdf file
# $1 - netcdf file
_nc_del_empty_varatt() {
    local nc_file=$1; shift
    local line_number=`_nc_get_gatt_line_from_ncdump $nc_file`
    local var_att_list="$(ncdump -h $nc_file | sed -n "1,${line_number}p"  | grep  '= "" ;$' | cut -d'=' -f1 | sed -e 's/\t//g'  | sed -e '/^$/d' | tr '\n' ' ')"
    local var att var_att

    if [[ ! -z $var_att_list ]]; then
        for var_att in $var_att_list; do
            var=`echo $var_att | cut -d':' -f1`
            att=`echo $var_att | cut -d':' -f2`
            nc_set_att -a $att,$var,d,c, $nc_file
        done
    fi
}
export -f _nc_del_empty_varatt

# return line from ncdump where the global attributes are listed
# $1 - netcdf file
_nc_get_gatt_line_from_ncdump() {
    local nc_file=$1; shift
    ncdump -h $nc_file | cat -n | grep "// global attributes:" | awk '{print $1}'
}
export -f _nc_get_gatt_line_from_ncdump

# return list of string time values
# $1 - netcdf file
_nc_get_time_values() {
    local nc_file=$1; shift
    local time_data=`ncdump -v TIME -t $nc_file | sed -n '/TIME = \".*\"/,$p' | tr -s ',\n' | tr -s "\n" ' ' | cut -d'=' -f2 | cut -d ';' -f1`

    echo $time_data
}
export -f _nc_get_time_values

# return valid CF gatt time coverage string
# $1 - one time str from ncdump
# example 2015-01-10 00:01:59.999993
_nc_transform_time_str() {
    local time_array="$1"; shift
    date --date="$time_array" +'%FT%TZ'
}
export -f _nc_transform_time_str

# returns a boolean to check if the time string of the first occurence looks like
# 2015-01-05 00:01:59.999993 or 2015-01-05 00:01:9.999993
# $1 - netcdf file
_nc_check_time_string_valid() {
    local nc_file=$1; shift
    _nc_get_time_values $nc_file | awk -F'"' '{ print $2 }' | grep -q -o -E  "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9].*\.[0-9]*$"
}
export -f _nc_check_time_string_valid
