## Current issues with the Queensland Wave dataset
Without taking into consideration which way is the best, here is a list of various issues
I came across with the Queensland wave dataset (minus the ones already found by Bene). There might be more issues

* empty resource/data
  * https://data.qld.gov.au/api/3/action/datastore_search?resource_id=5436c7e6-4d34-4968-97aa-8f105a64849a
* inconsistent variable names  
  * "id": "Date/ time 
  * "id": "Date/time
* ERROR - Service unavailable.
* inconsistent fillvalues
  * '-99.9' most data
  * '-9999' https://data.qld.gov.au/api/3/action/datastore_search?resource_id=e323539b-6682-4d9e-a2ac-c3c07d63875a
  * no fillvalue, but empty cells
  * ... others but not entirely sure yet
* wrong values
  * variable set to 0 https://data.qld.gov.au/api/3/action/datastore_search?resource_id=c82ee7d3-25e9-4642-819d-67c443929c90
* (not sure) data from 1976 ? https://data.qld.gov.au/api/3/action/datastore_search?resource_id=dc366f6a-957c-4d47-b582-05768f3c02b9
* Not all resources are Wave resources. We also have Current data
  * https://data.qld.gov.au/api/3/action/datastore_search?resource_id=bd8a6ec4-19bc-4557-8696-ce46ad307845
    
## issues in letting Talend do everything
Talend harvesters get quickly overly complicated when dealing with external web-services.
The idea that a Talend harvester, running as a cron job, to run, download the data, clean, 
update... assumes that the external web-service and data is perfect.

This is unfortunately/fortunately not the case.

I'm of the opinion that, for __ALL__ external web-services we retrieve data from and
 host, the Talend harvester is not the suitable tool to handle the whole process. 
It should be only created to process physical files.

All our system and tools are based around physical files:
- If we want to add a new file, or update it, this goes via a pipeline, 
a rather powerful tool. Talend will easily update the data on the database side.
- if we want to delete some data, again, we just run a po_s3_del command to remove 
any file from the database

As PO's, we don't have other tools or even credentials to deal with cleaning any data 
from the database(which is great in my opinion). If we used Talend for this, we are pretty much locked in.

Using talend to do everything means POs actually can't do anything with the data. It 
becomes almost impossible update/remove any data. Any full reprocess of the data becomes 
really complicated with any physical files to re-harvest. We sometimes deal with 
NRT web-services which remove their old on-going data which we have decided to keep. 
In this case, a data reprocess would be challenging. When dealing with physical files,
everything else becomes easier

Finally, it is also extremely harder to review a talend harvester than a python script

## recommended design for all external web-services data retrieve
#### harvest the data from an external web-service -> PYTHON

Python has all the toolboxes(pandas, numpy...) possible to quickly write some code to download and read data
from :
* wfs
* http(s) request
* ...

in various formats:
* json
* xml
* text
* ...

Many web-services would fail when they are triggered many times too quickly. This is easily
handled with Python by adding a ```retry``` decorator to a download function in order
to retry the downloading a defined amount of times.

#### cleaning the dataset  -> PYTHON
The data we collect from external contributors is never perfect. It is full of 
inconsistencies and this will always be the case.
* variable name/case changing 
* varying fill values
* empty variables
* bad values
* dealing with various timezones
* inconsistent time format
* ...

Writing any logic in java to handle those various cases as stated above becomes complicated and extremely time consuming for us PO's. 
it's a matter of days vs 10 minutes ratio. And it will also be, most likely, poorly written.
Debugging is also rather complicated in Talend.

#### creating physical files -> PYTHON
We are currently in the process of writing a common NetCDF generator from Json files. The process
will even be easier.

#### Harvesting the data to our database -> Pipeline v2 -> Talend
Another benefit of using the pipeline is that we can use the IOOS checker for more issues
with the data. 
We have also talked in the past of creating a checker on the actual data, as well as an
indexing database.
If we want to reduce the amount of harvesters, this is also a better way to go



