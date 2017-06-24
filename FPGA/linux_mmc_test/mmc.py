#!/usr/bin/python

import os
#import re
#import subprocess
import sys              # exception handling
import time

try:
    data = "Testing again, 1, 2, 3, 4..."
    dev = os.open("/dev/sdb", os.O_RDWR)
    os.write(dev, data)
    os.lseek(dev, 0, os.SEEK_SET)
    result = os.read(dev, len(data))
    if result != data:
        print "/dev/sdb i/o failed"
    else:
        print "ok"
    time.sleep(0.5)

except OSError as err:
    print("OS error: {0}".format(err))
except ValueError:
    print("Value error.")
except:
    print("Unexpected error:", sys.exc_info()[0])

