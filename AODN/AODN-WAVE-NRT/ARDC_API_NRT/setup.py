#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from setuptools import setup, find_packages


with open('README.md') as f:
    readme = f.read()

PACKAGE_NAME = 'ardc_nrt'


INSTALL_REQUIRES = [
    'jsonmerge',
    'netCDF4',
    'numpy',
    'pandas',
    'python_dateutil',
    'requests',
    'owslib',
    'lxml',
    'tenacity',
    'setuptools',
    'aodntools @ git+https://github.com/aodn/python-aodntools.git@1.5.4#egg=aodntools',
]


PACKAGE_DATA = {
    'ardc_nrt.config.omc': ['*.json'],
    'ardc_nrt.config.sofar': ['*.json'],
    'ardc_nrt.config.bom': ['*.json'],
}
PACKAGE_EXCLUDES = ['test*',
                    'config/omc/secrets.json',
                    'config/sofar/secrets.json']

TESTS_REQUIRE = [
    'pytest',
    'ipython',
    'ipdb'
]

EXTRAS_REQUIRE = {
    'testing': TESTS_REQUIRE,
    'interactive': TESTS_REQUIRE
}


setup(
    name=PACKAGE_NAME,
    version='0.1.0',
    description='ARDC Wave API access and creation of CF compliant NetCDF files',
    long_description=readme,
    author='Laurent Besnard',
    author_email='laurent.besnard@utas.edu.au',
    url='https://github.com/aodn/data-services/tree/master/AODN/ARDC_WAVE_API_NRT',
    install_requires=INSTALL_REQUIRES,
    packages=find_packages(exclude=PACKAGE_EXCLUDES),
    scripts=['ardc_nrt/ardc_sofar_nrt.py',
             'ardc_nrt/ardc_bom_nrt.py',
             'ardc_nrt/ardc_omc_nrt.py'],
    package_data=PACKAGE_DATA,
    test_suite='test_ardc_nrt',
    tests_require=TESTS_REQUIRE,
    extras_require=EXTRAS_REQUIRE,
    zip_safe=False,
    python_requires='>3.8',
    classifiers=[
        'Development Status :: 5 - Production/Stable',
        'Intended Audience :: Developers',
        'Natural Language :: English',
        'License :: OSI Approved :: GNU General Public License v3 (GPLv3)',
        'Programming Language :: Python',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.8',
        'Programming Language :: Python :: Implementation :: CPython',
    ]
)
