import argparse
import logging
import tempfile
import os
import sys


def args():
    """
    Returns the script arguments

        Parameters:

        Returns:
            vargs (obj): input arguments
    """
    parser = argparse.ArgumentParser(description='Creates NetCDF files from an ARDC WAVE API.\n '
                                     'Prints out the path of the new locally generated NetCDF file.')
    parser.add_argument('-o', '--output-path', dest='output_path', type=str, default=None,
                        help="output directory of FV00 netcdf file",
                        required=True)
    parser.add_argument('-p', '--push-to-incoming', dest='incoming_path', type=str, default=None,
                        help="incoming directory for files to be ingested by AODN pipeline (Optional)",
                        required=False)
    vargs = parser.parse_args()

    if vargs.output_path is None:
        vargs.output_path = tempfile.mkdtemp()

    if vargs.incoming_path:
        if not os.path.exists(vargs.incoming_path):
            raise ValueError('{path} not a valid path'.format(path=vargs.incoming_path))
    else:
        vargs.incoming_path = None

    if not os.path.exists(vargs.output_path):
        try:
            os.makedirs(vargs.output_path)
        except Exception:
            raise ValueError('{path} not a valid path'.format(path=vargs.output_path))
            sys.exit(1)

    return vargs


class IMOSLogging:

    def __init__(self):
        self.logging_filepath = []
        self.logger = []

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
        # closes the handlers of the specified logger only
        x = list(self.logger.handlers)
        for i in x:
            self.logger.removeHandler(i)
            i.flush()
            i.close()
