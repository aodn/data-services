# IMOS Compliance Checker Plugin

This is a checker for compliance with the [IMOS NetCDF Conventions](https://s3-ap-southeast-2.amazonaws.com/content.aodn.org.au/Documents/IMOS/Conventions/IMOS_NetCDF_Conventions.pdf).

It works with the [ioos/compliance-checker](https://github.com/ioos/compliance-checker).


### Installation

#### Core compliance-checker
To use the latest version of the IOOS core checker code, install it first directly from their GitHub repo:
```bash
pip install git+ssh://github.com/aodn/compliance-checker.git#egg=compliance-checker
```
Otherwise `pip` will grab the latest *release* from PyPI when you install the plugin.

#### IMOS plugin
```bash
git clone --depth=1 git@github.com:aodn/data-services.git
cd data-services/lib/cc_plugin_imos
pip install -e .
```
The `--depth=1` prevents git unnecessarily cloning the entire history of the data-services repository.


### Testing

```bash
cd data-services/lib/cc_plugin_imos
python setup.py test -s cc_plugin_imos.tests
```


### Usage

`compliance-checker -t=imos file.nc`

Run `compliance-checker -h` for help on command-line options.
