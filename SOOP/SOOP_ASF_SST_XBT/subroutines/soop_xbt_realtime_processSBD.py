#!/usr/bin/env python3.5
# -*- coding: utf-8 -*-
"""
Process SBD binary files
Please read ../doc/Devil ...pdf to understand how the files are written
"""

import datetime
import logging
import os
import sys
import time

from ship_callsign import ship_callsign_list

logger = logging.getLogger(__name__)


class soop_xbt_realtime_processSBD:

    def __init__(self, logger=None):
        self.sbddataFolder   = None
        self.ships           = ship_callsign_list()
        self.logger          = logger or logging.getLogger(__name__)
        self.csv_output_path = []
        self.script_time     = time.strftime("%a, %d %b %Y %H:%M:%S",
                                         time.localtime())
        self.csv_file_path   = []
        # Use this to convert target modified time into local time
        self.timezone_offset = time.altzone

    def handle_year(self, modulo_year_data):
        """
        Year is stored as the modulo of modulus 16 and expected to be in UTC
        This function is created with the idea we're processing Near Real Time
        data. So not expecting that data can be 15+ years older that the time it
        is being processed.
        Storing this data as modulo 16 sounds like a terrible choice since
        every 16 years, we find again the same values. As the project started in
        2008 with a mod value equal to 8, the mod value is reseted to 0 in 2016,
        2032 ... This gives us of course of few years ... but still... this is
        BAD
        """
        modulus             = 16
        now                 = datetime.datetime.utcnow()
        year_machine        = now.year
        modulo_year_machine = year_machine % modulus # UTC maachine time

        year_data           = []

        if modulo_year_machine == 0 and modulo_year_data > 1:
            # As it does not make sense that the machine be for ex in year 2016
            # and data in year 2017, then this actually means that if the
            # modulo_year_data is greater than 1, it is before 2016
            year_data = year_machine - modulus + modulo_year_data

        elif modulo_year_machine == modulo_year_data:
            year_data = year_machine

        elif modulo_year_machine > modulo_year_data:
            year_data = year_machine -  modulo_year_data

        elif modulo_year_machine < modulo_year_data:
            # this is impossible, back to the future
            logger.error('Impossible modulo_year_machine < modulo_year_data')

        return year_data

    def handle_sbd_file(self, fname, csv_output_path):
        self.csv_output_path = csv_output_path

        data               = {}
        err                = ""
        errInvalid         = ""

        f = open(fname, "rb")
        # There should be 5 bytes of headers in file to chuck
        resId = f.read(2)

        if resId == "C2" or resId == "C3":
            err = fname + " appears to have the correct header " + \
                    resId + " in the wrong place at byte 0"
            self.logger.error(err)
            data['incorrectHeaders'] = resId
        else:
            f.read(3)  # skip 3 bytes
            resId = f.read(2)

        if resId == "C2" or resId == "C3":
            data['fname'] = fname

            # this id is meaningless??
            res        = self.str_2_int_str(resId)
            data['id'] = res

            # Byte 2
            res             = f.read(1)
            data['drop_id'] = self.str_2_int_str(res)  # Drop number of the day

            # Byte 3
            res           = f.read(1)
            res           = self.str_2_bin(res)
            data['year']  = str(self.handle_year(self.bin_2_int(res[:4])))
            # month  is stored from 0 -11
            data['month'] = str(
                int(self.bin_2_int_str(res[4:])) + 1).zfill(2)

            # Byte 4, 5
            res            = f.read(2)
            res            = self.str_2_bin(res)
            data['day']    = self.bin_2_int_str(res[:5]).zfill(2)
            data['hour']   = self.bin_2_int_str(
                res[5: 10]).zfill(2)
            data['minute'] = self.bin_2_int_str(
                    res[10:]).zfill(2)

            # Byte 6 to 10
            res = f.read(5)
            res = self.str_2_bin(res)
            data['lon'] = str(float(self.bin_2_int_str(res[:20])) / 2900)
            data['lat'] = str(
                float(self.bin_2_int_str(res[20:])) / 2900 - 90)

            # Byte 11, 12, 13
            res                  = f.read(3)  # byte 11-13
            res                  = self.str_2_bin(res)
            # self.bin_2_int_str(res[2:7]) #   Number of Points MSB
            data['quality_flag'] = self.bin_2_int_str(
                    res[:1])  # quality flag

            if data['quality_flag'] == '0':
                # WARNING : is it really wwhat this is suppose to happen ? if
                # one bad data point, no profile created at all ?
                # comment : Loz 22/02/2016

                # It has bad data
                errInvalid = "QC Flag = 0 in: " + resId + " " + fname + \
                        " no CSV file written"
                self.logger.error(errInvalid)

            data['interface_code'] = self.bin_2_int_str(
                    res[7:14])  # Interface Code
            data['probe_code']     = self.bin_2_int_str(
                    res[14:])  # Probe type Code

            # Byte 14
            res            = f.read(1)
            res            = self.str_2_bin(res)
            data['points'] = self.bin_2_int_str(res)

            # Byte 15-23
            res              = f.read(9)
            data['callsign'] = self.char_str_2_ascii(res)
            if data['callsign'].lower() == "test":
                errInvalid = "Callsign is marked as TEST - Ignoring " + fname
                self.logger.error(errInvalid)

            # Byte 24, 25, 26
            temps  = []
            depths = []
            res    = f.read(3)
            while res != "":
                res = self.str_2_bin(res)

                # Temp in decimal / 200 - 3 = Temp in degrees
                # Convention is different from example. but (/200 -3) is the
                # correct data transformation
                temperature = str(
                        round(float(int(res[:13], 2))/200 -3, 4))

                # make into a decimal int then into a float then
                # divide by 2
                depth       = str(float(int(res[13:], 2)) / 2)
                temps.append(temperature)
                depths.append(depth)
                res         = f.read(3)

            data['temps']  = temps
            data['depths'] = depths

        else:
            # It has invalid data
            errInvalid = "Invalid file. Unrecognised resId: %s %s" \
                    % (resId, fname)
            self.logger.error(errInvalid)

        f.close()

        if len(data) > 10 and len(errInvalid) == 0:
            # create a CSV file for this SDB file
            self.write_csv(data, self.csv_output_path)

        return self.csv_file_path

    def write_csv(self, data, currDir):
        """
        creates a  CSV file for each SBD file
        suggested use is to run SQL then delete it
        """
        data.update(self.get_extras())

        # sort into folders based around shipname
        if (data['callsign'] in self.ships):

            csvDir = os.path.join(self.csv_output_path,
                                  data['callsign'] + "_" +
                                  self.ships[data['callsign']], data['year'])

            if(not os.path.exists(csvDir)):
                try:
                    os.makedirs(csvDir)
                except:
                    err = "problem  writing to the CSV Directory " + \
                            csvDir + " exiting..  "
                    self.logger.error(err)
                    sys.exit()


            filename  = data['fname'].replace(".sbd", "")
            stringArr = filename.split("_")
            filename  = stringArr[len(stringArr)-1]

            imos_filedate = data['year'] + data['month'] + data['day'] + "T" +\
                    data['hour'] + data['minute'] + "00Z"
            filename = "IMOS_SOOP-XBT_T_" + imos_filedate + "_" + \
                    data['callsign'] + "_" + filename + "_FV00.csv"

            self.logger.info('%s => %s' % (os.path.basename(data['fname']),
                                           os.path.basename(filename)))
            # overwrite existing files.
            self.csv_file_path = os.path.join(csvDir, filename)
            with open(self.csv_file_path, 'w+') as f:
                f.write("Project:,%s\r\n" % data['project'])
                f.write("Source:,%s\r\n" % data['source'])
                f.write("Latitude:,%s\r\n" % data['lat'])
                f.write("Longitude: ,%s\r\n" % data['lon'])
                f.write("Date/Time:,%s/%s/%s %s:%s\r\n" %
                        (data['day'], data['month'], data['year'], data['hour'], \
                         data['minute']))
                f.write("This file Created:,%s\r\n" % data['date_created'])
                f.write("Platform Code:,%s\r\n" % data['callsign'])
                f.write("Vessel Name:,%s\r\n" % self.ships[data['callsign']])
                f.write("XBT Recorder Type:,%s,%s\r\n" % (data['interface_code'], \
                        data['recorder_probe_notes']))
                f.write("XBT Probe Type Fallrate Equation:,%s,%s\r\n" %
                        (data['probe_code'], data['recorder_probe_notes']))
                f.write("Comment,%s\r\n" % data['comment'])
                f.write("Metadata:,%s\r\n\r\n" % data['metadata'])
                f.write("Depth Units:,Metre\r\n\r\n")
                f.write("Temperature Units:,Degrees Celsius\r\n\r\n")
                f.write("Depth,Temperature\r\n")

                for index in range(len(data['depths'])):
                    f.write('%s,%s\r\n' % (data['depths'][index],
                                           data['temps'][index]))

        else:
            err = ('No ship name known for %s : %s. No CSV profile created'
                   % (data['fname'], data['callsign']))
            self.logger.error(err)

    def char_str_2_ascii(self, string):
        """
        converts string of chars to ascii
        """
        thelist = list(string)
        collector = []
        for char in thelist:
            if ord(char) < 48 or ord(char) > 127:
                pass
            else:
                collector.append(char)
        return "".join(collector)

    def str_2_bin(self, string):
        """
        converts string of ascii to a binary representation
        """
        thelist   = list(string)
        collector = []
        for char in thelist:
            collector.append(self.ascii_to_bin(char))
        return "".join(collector)

    def ascii_to_bin(self, char):
        """
        converts ascii char (byte) to a binary representation
        """
        ascii = ord(char)
        bin   = []

        while (ascii > 0):
            if (ascii & 1) == 1:
                bin.append("1")
            else:
                bin.append("0")
            ascii = ascii >> 1

        bin.reverse()
        binary  = "".join(bin)
        zerofix = (8 - len(binary)) * '0'

        return zerofix + binary

    def bin_2_int(self, bin):
        if bin == "":
            return []
        else:
            return int(bin, 2)

    def bin_2_int_str(self, bin):
        """
        returns binary representation back to decimal string
        """
        if bin == "":
            return ""
        else:
            return str(int(bin, 2))

    def str_2_int_str(self, string):
        """
        wrapper function:
        takes a string of ascii bytes
        converts each byte to a binary representation and concatanting each
        convert result back to decimal
        """
        res = self.str_2_bin(string)
        return self.bin_2_int_str(res)

    def get_extras(self):
        data = {}
        data['date_created'] = self.script_time
        data['source'] = "XBT Data"
        data['recorder_probe_notes'] = "See WMO code table 4770 for the information corresponding to the value "
        data['comment']              = "For more information on how to acknowlege distribute and cite this dataset " \
            "please refer to the IMOS website http://imos.org.au"
        data['metadata'] = "https://catalogue-123.aodn.org.au/geonetwork/srv/en/metadata.show?uuid=35234913-aa3c-48ec-b9a4-77f822f66ef8"
        data['project'] = "Integrated Marine Observing System (IMOS)"
        return data
