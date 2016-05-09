# IMOS Compliance Checker Plugin

This is a checker for compliance with the [IMOS NetCDF Conventions](https://s3-ap-southeast-2.amazonaws.com/content.aodn.org.au/Documents/IMOS/Conventions/IMOS_NetCDF_Conventions.pdf).

It works with the [ioos/compliance-checker](https://github.com/ioos/compliance-checker).


### Installation

```bash
git clone git@github.com:aodn/data-services.git
cd data-services/lib/cc_plugin_imos
pip install -e .
```

or simply

`pip install -e git+git@github.com:aodn/data-services.git#egg=cc_plugin_imos&subdirectory=lib/cc_plugin_imos`


### Testing

```bash
cd data-services/lib/cc_plugin_imos
python setup.py test -s cc_plugin_imos.tests
```


### Usage

`compliance-checker -t=imos file.nc`

Run `compliance-checker -h` for help on command-line options.
