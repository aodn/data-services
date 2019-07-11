# ANMN Time Series aggregator

The `aggregated_timeseries` script, collects data for a selected variable from all instruments at a particular site between selected dates, and outputs a single netCDF file with the selected variable concatenated from all deployments. 



## HOW TO run the script

`python aggregated_timeseries.py`

The configuration parameters are defined in TSaggr_config.json:

```
{
"varname":      "TEMP",
"site":         "NRSKAI",
"featuretype":  "timeseries",
"fileversion":  1,
"realtime":     "no",
"datacategory": "Temperature",
"timestart":    "2018-01-01",
"timeend":      "",
"filterout":    "Velocity"
}
```

Sample prototypes are available through AODN-THREDDS [demo folder](http://thredds.aodn.org.au/thredds/catalog/IMOS/eMII/demos/timeseries_products/aggregated_timeseries/draft1/catalog.html)
