using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using Microsoft.Win32.SafeHandles;
using NativeUsbLib;

namespace M2TestModule
{
    public class Hardware
    {
        // Publics

        // Private fields

        // M2 hardware
        int idVendor = 0x1535;
        int idProduct = 0x0021;
        SafeFileHandle hid = null;
        FileStream ioStream;
        const int UsbIoBuffer = 256;    // bytes, 256 is probably sufficient (max packet size)
        const int UsbTimeout = 500;    // Default timeout 5sec
        string hidDevice { get; set; }
        string logFile { get; set; }

        // Milliseconds to wait for the M2 MCU to execute a command
        int mcuExecuteTimeout { get; set; }

        /// <summary>
        /// Open hardware.
        /// </summary>
        /// <param name="logFile"></param>
        /// <returns>0 if Ok, 100 on failure to open device</returns>
        public int StartupHardware(string logFile)
        {
            try
            {
                mcuExecuteTimeout = 500;    // half a second for now...
                this.logFile = logFile;
                hidDevice = GetDeviceName();
                if (hidDevice.Length == 0)
                {
                    M2Module.WriteMessage(string.Format("Sango M2 HID device VID_{0:x04}, PID_{1:x04} was not found.", idVendor, idProduct));
                    return 100;
                }
                if (!Open(hidDevice))
                {
                    M2Module.WriteMessage(string.Format("Error opening M2(HID) device {0}", hidDevice));
                    return 100; // "**ERROR, failed opening M2 HID device**";
                }
                return 0;
            }
            catch (Exception ex)
            {
                M2Module.WriteMessage(string.Format("Error writing HID report:{0}", ex.Message));
                return 100;
            }
        }

        public void Close()
        {
            try
            {
                if (hid != null && !hid.IsInvalid && !hid.IsClosed)
                {
                    ioStream.Close();
                    hid.Close();
                }
            }
            catch (Exception ex)
            {
                M2Module.WriteMessage(string.Format("Exception closing M2 HID device:{0}", ex.Message));
            }
        }

        // <returns>true on success, false on error</returns>
        public bool WriteCommand(byte[] command)
        {
            try
            {
                int REPORT_SIZE = 32 + 1;
                byte[] cmd = new byte[REPORT_SIZE];
                cmd[0] = 0; // report number, required
                for (var k = 0; k < command.Length && k < REPORT_SIZE - 1; k++)
                    cmd[k + 1] = command[k];
                bool success = UsbApi.HidD_SetOutputReport(hid, cmd, cmd.Length);
                return success;
            }
            catch (Exception ex)
            {
                M2Module.WriteMessage(string.Format("Error writing command to M2:{0}",
                                         ex.Message));
                return false;
            }
        }

        // <returns>true on success, false on error</returns>
        public bool WriteCommand(string command)
        {
            try
            {
                int REPORT_SIZE = 32 + 1;
                byte[] cmd = new byte[REPORT_SIZE];
                cmd[0] = 0; // report number, required
                //for (var k = 0; k < command.Length && k < REPORT_SIZE - 1; k++)
                //    cmd[k + 1] = command[k];
                bool success = UsbApi.HidD_SetOutputReport(hid, cmd, cmd.Length);
                return success;
            }
            catch (Exception ex)
            {
                M2Module.WriteMessage(string.Format("Error writing command to M2:{0}",
                                         ex.Message));
                return false;
            }
        }

        /*
         * Read the response.
         * Returns data in response array.
         * Returns status byte, 0=Success
         */
        public int ReadResponse(ref byte[] response)
        {
            int status = 0;
            int REPORT_SIZE = 32 + 1;
            response = new byte[REPORT_SIZE];
            for (var k = 0; k < REPORT_SIZE; k++) response[k] = 0;
            try
            {
                bool success = UsbApi.HidD_GetInputReport(hid, response, REPORT_SIZE);
                // report number is always 1st byte., status is 2nd byte
                if (response[1] != 0)
                {
                    status = (int)response[1];
                    //M2Module.WriteMessage(string.Format("Error:{0:x02} ", rsp[1]) + ErrorDescription(rsp[1]);
                }
                // Response is at index 6, plus HID report code in byte 0 = 7
                Array.Copy(response, 7, response, 0, REPORT_SIZE - 7);
            }
            catch (Exception ex)
            {
                M2Module.WriteMessage(string.Format("**ERROR writing command to M2:{0}**",
                                            ex.Message));
            }
            return status;
        }

        /*
         * Read the response.
         * Returns data in response array.
         * Returns status byte, 0=Success
         */
        public int ReadResponse(ref string response)
        {
            int status = 0;
            response = "";
            try
            {
                //bool success = UsbApi.HidD_GetInputReport(hid, response, REPORT_SIZE);
                //// report number is always 1st byte., status is 2nd byte
                //if (response[1] != 0)
                //{
                //    status = (int)response[1];
                //    //M2Module.WriteMessage(string.Format("Error:{0:x02} ", rsp[1]) + ErrorDescription(rsp[1]);
                //}
                //// Response is at index 6, plus HID report code in byte 0 = 7
                //Array.Copy(response, 7, response, 0, REPORT_SIZE - 7);
            }
            catch (Exception ex)
            {
                M2Module.WriteMessage(string.Format("**ERROR writing command to M2:{0}**",
                                            ex.Message));
            }
            return status;
        }

        public int ExecuteCommand(byte[] command, ref byte[] response)
        {
            int status = 0;
            if (WriteCommand(command))
            {
                Thread.Sleep(20);
                status = ReadResponse(ref response);
                int counter = mcuExecuteTimeout / 25;
                while (status == M2FwDefs.ERR_RESPONSE_QUEUE_EMPTY &&
                        counter-- > 0)
                {
                    Thread.Sleep(25);
                    status = ReadResponse(ref response);
                }
            }
            else status = M2FwDefs.ERR_UNKNOWN; // Failed writing to M2, USB error, etc.
            return status;
        }

        public int ExecuteCommand(string command, ref string response)
        {
            int status = 0;
            if (WriteCommand(command))
            {
                Thread.Sleep(20);
                status = ReadResponse(ref response);
                int counter = mcuExecuteTimeout / 25;
                while (status == M2FwDefs.ERR_RESPONSE_QUEUE_EMPTY &&
                        counter-- > 0)
                {
                    Thread.Sleep(25);
                    status = ReadResponse(ref response);
                }
            }
            else status = M2FwDefs.ERR_UNKNOWN; // Failed writing to M2, USB error, etc.
            return status;
        }

        public string ErrorDescription(int errorCode)
        {
            switch (errorCode)
            {
                case 0:
                    return "Success";
                case M2FwDefs.ERR_CMD_NO_MEMORY:
                    return "[1] Error allocating memory for Command";
                case M2FwDefs.ERR_INVALID_CMD:
                    return "[2] Error, invalid command";
                case M2FwDefs.ERR_INVALID_ARGS:
                    return "[3] Error, invalid command argument(s)";
                case M2FwDefs.ERR_INVALID_I2C_BUS:
                    return "[4] Error, invalid I2C enable, 0 to 5 are valid";
                case M2FwDefs.ERR_CMD_QUEUE_FULL:
                    return "[5] Error, command queue is full";
                case M2FwDefs.ERR_CMD_QUEUE_NULL:
                    return "[6] Error, command queue was not created";
                case M2FwDefs.ERR_CMD_QUEUE_RD_TIMEOUT:
                    return "[7] Error, timeout waiting for command queue";
                case M2FwDefs.ERR_QUEUE_FULL:
                    return "[8] Error, basic queue full";
                case M2FwDefs.ERR_QUEUE_NULL:
                    return "[9] Error, basic queue not created";
                case M2FwDefs.ERR_QUEUE_RD_TIMEOUT:
                    return "[10] Error, basic queue timeout";
                case M2FwDefs.ERR_QUEUE_NOT_CREATED:
                    return "[11] Error, response queue not created";
                case M2FwDefs.ERR_RESPONSE_QUEUE_EMPTY:
                    return "[12] Error, response queue is empty";
                case M2FwDefs.ERR_INCOMPLETE_I2C_WRITE:
                    return "[13] Error, incomplete I2C write";
                case M2FwDefs.ERR_INCOMPLETE_I2C_READ:
                    return "[14] Error, incomplete I2C read";
                case M2FwDefs.ERR_SPI_IO_ERROR:
                    return "[15] Error, SPI IO problem";
                case M2FwDefs.ERR_READ_SIZE_TOO_LARGE:
                    return "[15] Error, HID read size too large(>32 bytes total)";
                case M2FwDefs.ERR_INVALID_SPI_DEVICE:
                    return "[17] Error, invalid SPI device specified";
                case M2FwDefs.ERR_I2C_NACK:
                    return "[18] Error, I2C NACK";
                case M2FwDefs.ERR_I2C_ARBLOST:
                    return "19] Error, I2C arbitration lost";
                case M2FwDefs.ERR_I2C_BUSERR:
                    return "[20] Error, I2C bus error";
                case M2FwDefs.ERR_I2C_BUSY:
                    return "[21] Error, I2C busy";
                case M2FwDefs.ERR_I2C_SLAVENAK:
                    return "[22] Error, I2C slave NACK";
                case M2FwDefs.ERR_I2C_UNKNOWN:
                    return "[23] Error, unknown I2C problem";
                case M2FwDefs.ERR_CFG_ADC:
                    return "[24] Error, configure ADC error";
                case M2FwDefs.ERR_INVALID_PWM_DUTY_CYCLE:
                    return "[25] Error, invalid PWM duty cycle";
                case M2FwDefs.ERR_INVALID_PWM_RATE:
                    return "[26] Error, invalid PWM rate";
                case M2FwDefs.ERR_WRITING_CALDATA:
                    return "[27] Error writing cal data to EEPROM";
                case M2FwDefs.ERR_READING_CALDATA:
                    return "[28] Error reading cal data from EEPROM";
                case M2FwDefs.ERR_TEMPADC_NOTREADY:
                    return "[29] Error, temperature ADC not ready";
                case M2FwDefs.ERR_TEMPADC_INVALID:
                    return "[30] Error, temperature ADC not valid";
                case M2FwDefs.ERR_INVALID_RF_CHANNEL:
                    return "[31] Error, invalid RF channel. 1-4 allowed";
                case M2FwDefs.ERR_CALDATA_INVALID:
                    return "[32] Error, caldata invalid";
                case M2FwDefs.ERR_LOW_POWER_NOT_SUPPORTED:
                    return "[33] Error, power below 40dBm not supported yet";
                case M2FwDefs.ERR_CALDATA_TOO_LARGE:
                    return "[34] Error, caldata too large";
                case M2FwDefs.ERR_INVALID_IQOFFSET:
                    return "[35] Error, invalid IQ offset value";
                case M2FwDefs.ERR_NO_PLL_LOCK:
                    return "[36] Error, no PLL_LOCK detected";
                case M2FwDefs.ERR_CMD_TIMEOUT:
                    return "[37] Error, command timeout";
                case M2FwDefs.ERR_PANEL_NOT_FOUND:
                    return "[38] Error, panel not found in panel list";
                case M2FwDefs.ERR_TOO_MANY_POPUPS:
                    return "[39] Error, too many popups (>32)";
                case M2FwDefs.ERR_CREATING_PANEL:
                    return "[40] Error, can't create panel";
                case M2FwDefs.ERR_LCD_CMD_BUSY:
                    return "[41] Error, LCD panel already executing a command";
                case M2FwDefs.ERR_DRAW_FOCUS:
                    return "[42] Error, can't draw focus";
                case M2FwDefs.ERR_DRAW_PANEL:
                    return "[43] Error, can't draw panel";
                case M2FwDefs.ERR_LCD_UNKNOWN_KEY:
                    return "[44] Error, unknown LCD key, check LCD connection";

                case M2FwDefs.ERR_TAG_NOT_FOUND:
                    return "[45] Error, Tag not found";

                case M2FwDefs.ERR_TAG_TOO_LONG:
                    return "[46] Error, Tag name too long(16 max)";

                case M2FwDefs.ERR_TAG_NO_EQUALS:
                    return "[47] Error, Tag data missing = sign";

                case M2FwDefs.ERR_TAG_NAME_LEN:
                    return "[48] Error, Tag name >16 character limit";

                case M2FwDefs.ERR_TAG_VAL_LEN:
                    return "[49] Error, Tag value >255 byte limit";

                case M2FwDefs.ERR_NO_TAG_DELIMITER:
                    return "[50] Error, Tag data missing delimiter(| character in EEPROM)";

                case M2FwDefs.ERR_TAG_GENERAL:
                    return "[51] Error, unknown Tag error";


                case M2FwDefs.ERR_INVALID_PNL_TYPE:
                    return "[60] Error, invalid panel type";

                case M2FwDefs.ERR_CHECKBOX_SETUP:
                    return "[61] Error, invalid checkbox setup";

                case M2FwDefs.ERR_NO_MEMORY:
                    return "[62] Error, out of memory";

                case M2FwDefs.ERR_I2C_ZEROBYTES:
                    return "[63] Error, 0 byte length in I2C read or write";

                case M2FwDefs.ERR_SPI_ZEROBYTES:
                    return "[64] Error, 0 byte length in SPI IO";

                default:
                case M2FwDefs.ERR_UNKNOWN:
                    return "[100] Unknown error";
            }
        }

        // private methods

        string GetDeviceName()
        {
            string hidDevicePath = "";

            Guid guidHid;
            UsbApi.HidD_GetHidGuid(out guidHid);
            IntPtr handle = UsbApi.SetupDiGetClassDevs(ref guidHid, 0, IntPtr.Zero, UsbApi.DIGCF_PRESENT | UsbApi.DIGCF_DEVICEINTERFACE);
            if (handle.ToInt64() != UsbApi.INVALID_HANDLE_VALUE)
            {
                IntPtr ptr = Marshal.AllocHGlobal(UsbApi.MAX_BUFFER_SIZE);
                bool success = true;
                for (int i = 0; success; i++)
                {
                    // Create a device info data structure.
                    var deviceInfoData = new UsbApi.SP_DEVINFO_DATA();
                    deviceInfoData.cbSize = IntPtr.Size == 8 ? 32 : Marshal.SizeOf(deviceInfoData);
                    // Start the enumeration.
                    success = UsbApi.SetupDiEnumDeviceInfo(handle, i, ref deviceInfoData);
                    if (success)
                    {
                        // Create a device interface data structure.
                        var deviceInterfaceData = new UsbApi.SP_DEVICE_INTERFACE_DATA();
                        deviceInterfaceData.cbSize = Marshal.SizeOf(deviceInterfaceData);

                        // Start the enumeration.
                        success = UsbApi.SetupDiEnumDeviceInterfaces(handle, IntPtr.Zero, ref guidHid,
                                                                     i, ref deviceInterfaceData);
                        if (success)
                        {
                            // Build a device interface detail data structure.
                            var deviceInterfaceDetailData = new UsbApi.SP_DEVICE_INTERFACE_DETAIL_DATA();
                            // Account for 64-bit or 32-bit systems
                            deviceInterfaceDetailData.cbSize = Marshal.SystemDefaultCharSize + (IntPtr.Size == 8 ? 6 : 4); // 4 + Marshal.SystemDefaultCharSize; // trust me :)

                            // Now we can get some more detailed informations.
                            int nRequiredSize = 0;
                            const int nBytes = UsbApi.MAX_BUFFER_SIZE;
                            if (UsbApi.SetupDiGetDeviceInterfaceDetail(handle, ref deviceInterfaceData,
                                                                        ref deviceInterfaceDetailData,
                                                                        nBytes, ref nRequiredSize,
                                                                        ref deviceInfoData))
                            {
                                string strSearch = string.Format("vid_{0:x4}&pid_{1:x4}",
                                                                    idVendor,
                                                                    idProduct);
                                if (deviceInterfaceDetailData.DevicePath.Contains(strSearch))
                                {
                                    Debug.WriteLine(string.Format("HidPath:{0}", deviceInterfaceDetailData.DevicePath));
                                    hidDevicePath = deviceInterfaceDetailData.DevicePath;
                                    break;
                                }
                            }
                        }
                    }
                }
                Marshal.FreeHGlobal(ptr);
                UsbApi.SetupDiDestroyDeviceInfoList(handle);
            }
            return hidDevicePath;
        }

        /// <summary>
        /// Opens device for read/write
        /// </summary>
        /// <returns>true on success, false on failure.
        /// On failure the system error message is 
        /// written to stdout.
        bool Open(string hidDevice)
        {
            hid = UsbApi.CreateFile(hidDevice,
                                    UsbApi.GENERIC_READ | UsbApi.GENERIC_WRITE,
                                    0, //UsbApi.FILE_SHARE_READ | UsbApi.FILE_SHARE_WRITE,
                                    IntPtr.Zero, (uint)UsbApi.OPEN_EXISTING,
                                    UsbApi.FILE_FLAG_OVERLAPPED, IntPtr.Zero);
            if (hid.IsInvalid)
            {
                var ex = new Win32Exception();
                M2Module.WriteMessage(string.Format("Error opening HID device:{0}",
                                        ex.Message));
                return false;
            }
            ioStream = new FileStream(hid, (FileAccess)FileAccess.ReadWrite, UsbIoBuffer, true);
            return true;
        }
    }
}
