#!/usr/bin/env python
"""
Class to simplify and standardise within eMII the use of the logging library for
Python

Howto:
in a new file

import os, sys
sys.path.insert(0, os.path.join(os.environ.get('DATA_SERVICES_DIR'), 'lib'))
from python.imos_logging import IMOSLogging

logging      = IMOSLogging()
logger       = logging.logging_start('/tmp/log.log')

logger.info('info')
logger.warning('warning')
logger.error('error')

logging.logging_stop()

-----------------------------------
author: Besnard, Laurent
email : laurent.besnard@utas.edu.au
"""

import logging
import os

class IMOSLogging():

    def __init__(self):
        self.logging_filepath = []
        self.logger           = []

    def logging_start(self, logging_filepath):
        """ start logging using logging python library
        output:
           logger - similar to a file handler
        """
        self.logging_filepath = logging_filepath
        if not os.path.exists(os.path.dirname(logging_filepath)):
            os.makedirs(os.path.dirname(logging_filepath))

        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger(__name__)
        self.logger.setLevel(logging.INFO)

        # create a file handler
        handler = logging.FileHandler(self.logging_filepath)
        handler.setLevel(logging.INFO)

        # create a logging format
        formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        handler.setFormatter(formatter)

        # add the handlers to the logger
        self.logger.addHandler(handler)
        return self.logger

    def logging_stop(self):
        """ close logging """
        #closes the handlers of the specified logger only
        x = list(self.logger.handlers)
        for i in x:
            self.logger.removeHandler(i)
            i.flush()
            i.close()
