#!/usr/bin/env python
"Unit tests for FileClassifier classes"

import os
import unittest
from dest_path import NonNetCDFFileClassifier, FileClassifierException


class TestNonNetCDFFileClassifier(unittest.TestCase):
    """Unit tests for ANMN FileClassifier class to handle non-netcdf
    files.  Other handling of netcdf files is already tested in
    test_file_classifier.

    Test cases:
    * PDF logsheet (with 6-digit date or full timestamp)
    * .cnv file (CTD profile)
    * .png plots from Toolbox

    Incorrect filenames should be handled before dest_path is called
    """

    def test_logsheet(self):
        filename = 'IMOS_ANMN-NRS_100702_NRSPHB_FV00_LOGSHT.pdf'
        dest_dir, dest_filename = os.path.split(NonNetCDFFileClassifier.dest_path(filename))
        self.assertEqual(dest_dir, 'IMOS/ANMN/NRS/NRSPHB/Field_logsheets')
        self.assertEqual(dest_filename, filename)

        filename = 'IMOS_ANMN-NRS_20150804T043000Z_NRSDAR_FV01_LOGSHT.pdf'
        dest_dir, dest_filename = os.path.split(NonNetCDFFileClassifier.dest_path(filename))
        self.assertEqual(dest_dir, 'IMOS/ANMN/NRS/NRSDAR/Field_logsheets')
        self.assertEqual(dest_filename, filename)


    def test_cnv(self):
        filename = 'IMOS_ANMN-NRS_CTP_090527_NRSNSI_FV00_CTDPRO.cnv'
        dest_dir, dest_filename = os.path.split(NonNetCDFFileClassifier.dest_path(filename))
        self.assertEqual(dest_dir, 'IMOS/ANMN/NRS/NRSNSI/Biogeochem_profiles/non-QC/cnv')
        self.assertEqual(dest_filename, filename)

        filename = 'IMOS_ANMN-NRS_CTP_120729T163000Z_NRSDAR_FV00_CTDPRO_01.cnv'
        dest_dir, dest_filename = os.path.split(NonNetCDFFileClassifier.dest_path(filename))
        self.assertEqual(dest_dir, 'IMOS/ANMN/NRS/NRSDAR/Biogeochem_profiles/non-QC/cnv')
        self.assertEqual(dest_filename, filename)

        filename = 'IMOS_ANMN-NRS_CDEKOSTUZ_140730_NRSROT_FV00_CTDPRO.cnv'
        dest_dir, dest_filename = os.path.split(NonNetCDFFileClassifier.dest_path(filename))
        self.assertEqual(dest_dir, 'IMOS/ANMN/NRS/NRSROT/Biogeochem_profiles/non-QC/cnv')
        self.assertEqual(dest_filename, filename)

    def test_plots(self):
        filename = 'IMOS_ANMN-WA_WATR20_FV01_WATR20-1502_LINE_TEMP_C-20150820T052407Z.png'
        dest_dir, dest_filename = os.path.split(NonNetCDFFileClassifier.dest_path(filename))
        self.assertEqual(dest_dir, 'IMOS/ANMN/WA/WATR20/plots')
        self.assertEqual(dest_filename, filename)

        filename = 'IMOS_ANMN-NRS_NRSYON_FV01_NRSYON-1406_SCATTER_UCUR_C-20150722T055014Z.png'
        dest_dir, dest_filename = os.path.split(NonNetCDFFileClassifier.dest_path(filename))
        self.assertEqual(dest_dir, 'IMOS/ANMN/NRS/NRSYON/plots')
        self.assertEqual(dest_filename, filename)


if __name__ == '__main__':
    unittest.main()
