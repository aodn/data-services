SOOP XBT DELAYED MODE PROCESSING
=============

This script can be used to convert SOOP XBT files orginal files into IMOS and CF compliant format

## USAGE

Files can be processed individually or as a batch
```bash
xbt_dm_imos_conversion.py -h  # HELP

xbt_dm_imos_conversion.py --input-edited-xbt-path FILE_PATH --output-folder OUTPUT_FOLDER --log-file /tmp/xbt/xbt.log
xbt_dm_imos_conversion.py -i INPUT_FOLDER -o OUTPUT_FOLDER -l /tmp/xbt/xbt.log
xbt_dm_imos_conversion.py -i INPUT_FOLDER -o OUTPUT_FOLDER
```

## INSTALLATION

The method of installation described below assumes a python virtual environment wrapper is installed.
See https://virtualenvwrapper.readthedocs.io/en/latest/install.html

```bash
WD=$HOME/.xbt_processing  # working directory
mkdir -p $WD & cd $WD
git clone --depth=1 git@github.com:aodn/data-services.git

mkvirtualenv xbt_work
easy_install distribute
pip install -r data-services/SOOP/SOOP_XBT/DELAYED/requirements.txt

# the following lines could be added to ~/.bashrc
WD=$HOME/.xbt_processing  # working directory
export PYTHONPATH=$PYTHONPATH:$WD/data-services/lib/python
export PATH=$PATH:$WD/data-services/SOOP/SOOP_XBT/DELAYED

# in order to restart the virtual environment
workon xbt_work
```

## Contact Support
for support contact:
Email: laurent.besnard@utas.edu.au
