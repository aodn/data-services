# Parameters Mapping or how to add a metadata header for CSV files

1. check that the parameters to add are listed in [data-services](https://github.com/aodn/data-services/tree/master/PARAMETERS_MAPPING)
    * ```parameters.csv``` list of available parameters and their ids
    * ```qc_flags.csv```
    * ```qc_scheme.csv```
    * ```unit_view.csv``` list the available units and their ids (cf names, longnames and id)

1. New parameters
    * needs to follow the IMOS vocabulary [BENE PLEASE UPDATE]

1. map the parameters for your dataset collection
    * update ```parameters_mapping.csv```. This is the file where all the information from the other files is brought together, and where a variable name as written in the column name of the csv is matched to a unique id for each parameters find in ```parameters.csv```, units find in ```unit_view.csv```, ...

1. Create view in Parameters mapping harvester: update the liquibase to update/include new views in the [harvester](https://github.com/aodn/harvesters/tree/master/workspace/PARAMETERS_MAPPING)
    * start your stack restoring the paramaters_mapping schema and the schema you are working on
    ```RestoreDatabaseSchemas: - schema: parameters_mapping, - schema: working_schema```
    * open pgadmin and access your stack-db to test the sql query that will be used to create/update the view in the parameters_mapping harvester, as it is easier to get a better understanding of the query before updating the liquibase via Talend
    * start  your pipeline box and Talend 
    * update liquidbase in the second components ```Create parameters_mapping views``` 
        * the query will crash because of 6 views are calling their respective dataset collection schema: 
    `aatams_biologging_shearwater_metadata_summary`; 
    `aatams_biologging_snowpetrel_metadata_summary`; 
    `aatams_sattag_dm_metadata_summary`; 
    `aatams_sattag_nrt_metadata_summary`; 
    `aodn_nt_sattag_hawksbill_metadata_summary`; 
    `aodn_nt_sattag_oliveridley_metadata_summary`
    * write the new view you are working on at the top of the liquidbase script, so Talend can run and create before crashing at `aatams_biologging_shearwater_metadata_summary` 
    * check stack database that the views are created as expected

1. merge the changes made in
    * [data-services](https://github.com/aodn/data-services/tree/master/PARAMETERS_MAPPING) 
    * [harvester](https://github.com/aodn/harvesters/tree/master/workspace/PARAMETERS_MAPPING) to test on RC before merging to production

1. test on RC, check the csv files a user can download from the portal

# Other information
The [PARAMETERS_MAPPING harvester](https://github.com/aodn/harvesters/tree/master/workspace/PARAMETERS_MAPPING) runs on a cron job daily , Monday to Friday.
It harvests the content of these 5 files into the parameters_mapping DB schema and create a `_metadata_summary` view for each of the collection listed (it is not IMOS specific, for example we have a mapping for the AODN `_WAVE_DM` + `NRT` collections)

