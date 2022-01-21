#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from setuptools import setup, find_packages


with open('README.md') as f:
    readme = f.read()

PACKAGE_NAME = 'ardc_nrt'


INSTALL_REQUIRES = [
    'aodntools',
    'jsonmerge',
    'netCDF4',
    'numpy',
    'pandas',
    'python_dateutil',
    'requests',
    'setuptools'
]

#INSTALL_REQUIRES = [
#    'pandas==1.2.5',
#    'aodntools',
#    'jsonmerge==1.8.0',
#    'netCDF4==1.5.8',
#    'numpy==1.22.2',
#    'python_dateutil==2.8.2',
#    'requests==2.27.1',
#    'setuptools==60.9.1'
#]


PACKAGE_DATA = {
    'ardc_nrt.config.omc': ['*.json'],
    'ardc_nrt.config.sofar': ['*.json'],

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
    dependency_links=[
        'https://github.com/aodn/python-aodntools/master'],
    packages=find_packages(exclude=PACKAGE_EXCLUDES),
    scripts=['ardc_nrt/ardc_sofar_nrt.py',
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

