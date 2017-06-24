
import re
import subprocess
import sys              # exception handling
import os
import win32file
#from py2 import win32file

WhichOs = "nt"
device_re = re.compile("Bus\s+(?P<bus>\d+)\s+Device\s+(?P<device>\d+).+ID\s(?P<id>\w+:\w+)\s(?P<tag>.+)$", re.I)

WhichOs = os.name
if WhichOs == "nt":
    print("WIndows USB devices:")

#def locate_usb():
#import win32file
    drive_list = []
    drivebits=win32file.GetLogicalDrives()
    for d in range(1,26):
        mask=1 << d
        if drivebits & mask:
            # here if the drive is at least there
            drname='%c:\\' % chr(ord('A')+d)
            t=win32file.GetDriveType(drname)
            if t == win32file.DRIVE_REMOVABLE:
                drive_list.append(drname)
                print(drname)
    #return drive_list


elif WhichOs == "linux":
    try:
        df = subprocess.check_output("lsusb", shell=True)
    except OSError as err:
        print("OS error: {0}".format(err))
    except ValueError:
        print("Value error.")
    except:
        print("Unexpected error:", sys.exc_info()[0])
        raise
else:
    print("Unknown OS, exiting")
    exit

devices = []
for i in df.split('\n'):
    if i:
        info = device_re.match(i)
        if info:
            dinfo = info.groupdict()
            dinfo['device'] = '/dev/bus/usb/%s/%s' % (dinfo.pop('bus'), dinfo.pop('device'))
            devices.append(dinfo)
print(devices)
