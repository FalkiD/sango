/*
 * Top level module for S4 hardware testing.
 * Provides public static method for other modules to access
 * the calling assemnbly's ShowMessage delegate to show
 * status messages.
 * 
 * If the delegate is null the messages still go into the log file.
 */
using System;
using System.IO;
using System.Diagnostics;
using System.Text;
using Interfaces;
using RFModule;

namespace S4TestModule
{
    public class S4Module : RFBaseModule, IErrors, IDebugging, ICommands
    {
        public static S4Module TopModule { get; set; }
        public static void WriteMessage(string message)
        {
            if (TopModule != null)
                TopModule.AppendLine(message);
        }

        S4Hardware _s4hw = null;

        /// <summary>
        /// On success, returns 0, S4 device has been opened.
        /// </summary>
        /// <param name="logFile"></param>
        /// <returns></returns>
        public override int Initialize(string logFile)
        {
            
            int status = base.Initialize(logFile);
            TopModule = this;
            _s4hw = new S4Hardware();
            if (_s4hw != null)
                status = _s4hw.StartupHardware(logFile);

            return status;
        }

        public override void Close()
        {
            if (_s4hw != null)
            {
                _s4hw.Close();
                _s4hw = null;
            }
        }

        // Properties
        public override string FirmwareVersion
        {
            get
            {
                throw new NotImplementedException();
            }
        }

        public override InstrumentInfo.InstrumentType HwType
        {
            get { return InstrumentInfo.InstrumentType.S4; }
        }

        public override string Status
        {
            get
            {
                throw new NotImplementedException();
            }
        }

        public override string HardwareInfo(ref bool demoMode, ref bool hiresMode)
        {
            string result = "";
            int status;
            string value = "";
            //if ((status = GetTag("SN", ref value)) == 0)
            //    result += ("SN=" + value + ",");
            //if ((status = GetTag("MD", ref value)) == 0)
            //    result += ("Model=" + value + ",");

            status = RunCmd("status\n", ref result);
            if (status == 0)
                result += value;
            else result = string.Format(" Read device info failed:{0}", ErrorDescription(status));

            //if ((status = GetTag("DM", ref value)) == 0 && value == "ON")
            //    demoMode = true;
            //else demoMode = false;
            demoMode = hiresMode = false;

            //cmd[0] = M2Cmd.ENABLE_RD;
            //status = RunCmd(cmd, ref rsp);
            //if (status == 0 && (rsp[0] & 0x80) != 0)
            //    hiresMode = true;
            //else hiresMode = false;

            return result;
        }

        /// <summary>
        /// Set Tag string data
        /// </summary>
        /// <param name="name"></param>
        /// <param name="value"></param>
        /// <returns></returns>
        public override int SetTag(string name, string value)
        {
            byte[] data = Encoding.ASCII.GetBytes(value);
            return _SetTag(name, data, false);
        }

        public override int SetTag(string name, byte[] value)
        {
            return _SetTag(name, value, true);
        }

        int _SetTag(string name, byte[] value, bool binary)
        {
            try
            {
                byte[] response = null;
                if (_s4hw != null)
                {
                    //byte[] nam_bytes = Encoding.ASCII.GetBytes(name);
                    //int offset = binary ? 3 : 2;
                    //byte[] cmd = new byte[1 + name.Length + offset + value.Length];
                    //cmd[0] = S4Cmd.SET_TAG;
                    //Array.Copy(nam_bytes, 0, cmd, 1, name.Length);
                    //if (binary)
                    //{
                    //    cmd[name.Length + 1] = 0x23;
                    //    cmd[name.Length + 2] = (byte)value.Length;
                    //}
                    //else
                    //    cmd[name.Length + 1] = 0x3d;
                    //Array.Copy(value, 0, cmd, name.Length + offset, value.Length);
                    //return _s4hw.ExecuteCommand(cmd, ref response);
                    return 0;
                }
                throw new ApplicationException("S4 hardware not initialized");
            }
            catch (Exception ex)
            {
                AppendLine(string.Format("SetTag() exception:{0}", ex.Message));
                return S4FwDefs.ERR_UNKNOWN;
            }
        }

        public override int GetTag(string name, ref string value)
        {
            try
            {
                if (_s4hw != null)
                {
                    byte[] data = null;
                    int status = GetTag(name, ref data);
                    if (status == 0)
                    {
                        int j;
                        for (j = 0; j < data.Length; ++j)
                            if (data[j] == 0)
                                break;
                        value = Encoding.ASCII.GetString(data, 0, j);
                    }
                    return status;
                }
                else
                    throw new ApplicationException("S4 hardware not initialized");
            }
            catch (Exception ex)
            {
                AppendLine(string.Format("GetTag() exception:{0}", ex.Message));
                return S4FwDefs.ERR_UNKNOWN;
            }
        }

        public override int GetTag(string name, ref byte[] value)
        {
            try
            {
                if (_s4hw != null)
                {
                    //byte[] nam_bytes = Encoding.ASCII.GetBytes(name);
                    //byte[] cmd = new byte[name.Length + 2];
                    //cmd[0] = S4Cmd.GET_TAG;
                    //Array.Copy(nam_bytes, 0, cmd, 1, name.Length);
                    //cmd[name.Length + 1] = 0;
                    //return _s4hw.ExecuteCommand(cmd, ref value);
                    return 0;
                }
                else
                    throw new ApplicationException("S4 hardware not initialized");
            }
            catch (Exception ex)
            {
                AppendLine(string.Format("GetTag() exception:{0}", ex.Message));
                return S4FwDefs.ERR_UNKNOWN;
            }
        }

        public override int ReadEeprom(int offset, ref byte[] data)
        {
            try
            {
                if (_s4hw != null)
                {
                    //byte[] cmd = new byte[3];
                    //cmd[0] = S4Cmd.RD_EEPROM;
                    //cmd[1] = (byte)offset;
                    //cmd[2] = (byte)((offset >> 8) & 0xff);
                    //return _s4hw.ExecuteCommand(cmd, ref data);
                    return 0;
                }
                else
                    throw new ApplicationException("S4 hardware not initialized");
            }
            catch (Exception ex)
            {
                AppendLine(string.Format("GetTag() exception:{0}", ex.Message));
                return S4FwDefs.ERR_UNKNOWN;
            }
        }

        public override int ReadI2C(int channel, int address, byte[] wrbytes, byte[] data)
        {
            try
            {
                if (channel < 0 || channel > 4)
                    throw new ApplicationException(string.Format("ReadI2C error, invalid S4 channel {0}, must be between 0 and 4", channel));

                if (_s4hw != null)
                {
                    string cmd;
                    if (address == 0x60) // driver
                    {
                        //    tmp[0] = 0xc0;
                        //    tmp[1] = (byte)(0x58 | ((channel-1)<<1));
                        //    tmp[2] = 0x90 | ();
                        cmd = string.Format("ir drv 0xc0 {0}", data.Length);
                    }
                    else                // pa
                    {
                        //    tmp[0] = 0xc2;
                        //    tmp[1] = 0x79;
                        //    cmd = string.Format("iw {0} 0x{1} 0x{2} 0x{3} 0x{4}",
                        //                            channel == 1 ? "" : "pa",
                        //                            tmp[0], tmp[1],
                        //                            data[0], data[1]);
                        cmd = string.Format("ir pa 0xc2 {0}");
                    }
                    string rsp = "";
                    int status = _s4hw.ExecuteCommand(cmd, ref rsp);
                    if(status == 0)
                    {
                        string[] strs = rsp.Split(new char[] { ':', ' ', '\r', '\n' });
                        if (strs.Length < 25)
                            return S4FwDefs.ERR_INCOMPLETE_I2C_READ;

                        for (int j = 0; j < 24; ++j)
                        {
                            data[j] = Convert.ToByte(strs[j+3], 16);
                        }
                    }
                    return status;
                }
                else
                    throw new ApplicationException("S4 hardware not initialized");
            }
            catch (Exception ex)
            {
                AppendLine(string.Format("ReadI2C() exception:{0}", ex.Message));
                return S4FwDefs.ERR_UNKNOWN;
            }
        }

        public override int WriteEeprom(int offset, byte[] data)
        {
            try
            {
                if (_s4hw != null)
                {
                    //byte[] cmd = new byte[3 + data.Length];
                    //cmd[0] = S4Cmd.WR_EEPROM;
                    //cmd[1] = (byte)offset;
                    //cmd[2] = (byte)((offset >> 8) & 0xff);
                    //Array.Copy(data, 0, cmd, 3, data.Length);
                    //byte[] rsp = null;
                    //return _s4hw.ExecuteCommand(cmd, ref rsp);
                    return 0;
                }
                else
                    throw new ApplicationException("S4 hardware not initialized");
            }
            catch (Exception ex)
            {
                AppendLine(string.Format("WriteEEPROM() exception:{0}", ex.Message));
                return S4FwDefs.ERR_UNKNOWN;
            }
        }

        /// <summary>
        /// ViewModel processes "WriteI2C format(hex):'CC AA NN B0 B1 Bn', C=channel, A=address, N=bytes, B0...Bn is data"
        /// For S4, channel 1 is driver, 2 is PA
        /// Driver address is 0x60, pa address is 0x61
        /// Bytes sent will always be 3
        /// </summary>
        /// <param name="channel"></param>
        /// <param name="address"></param>
        /// <param name="data"></param>
        /// <returns></returns>
        //
        public override int WriteI2C(int channel, int address, byte[] data)
        {
            try
            {
                if (channel < 0 || channel > 4)
                    throw new ApplicationException(string.Format("WriteI2C error, invalid S4 channel {0}, must be between 0 and 4", channel));

                if (_s4hw != null)
                {
                    //byte[] tmp = new byte[4];  // address/config bytes
                    string cmd;
                    if (address == 0x60) // driver
                    {
                        //    tmp[0] = 0xc0;
                        //    tmp[1] = (byte)(0x58 | ((channel-1)<<1));
                        //    tmp[2] = 0x90 | ();
                        cmd = string.Format("iw drv 0xc0 0x{0:x2} 0x{1:x2} 0x{2:x2}",
                                                data[0], data[1], data[2]);
                    }
                    else                // pa
                    {
                        //    tmp[0] = 0xc2;
                        //    tmp[1] = 0x79;
                        //    cmd = string.Format("iw {0} 0x{1} 0x{2} 0x{3} 0x{4}",
                        //                            channel == 1 ? "" : "pa",
                        //                            tmp[0], tmp[1],
                        //                            data[0], data[1]);
                        cmd = string.Format("iw pa 0xc2 0x79 0x{0:x2} 0x{1:x2}",
                                                data[0], data[1]);
                    }
                    string rsp = "";
                    return _s4hw.ExecuteCommand(cmd, ref rsp);
                }
                else
                    throw new ApplicationException("S4 hardware not initialized");
            }
            catch (Exception ex)
            {
                AppendLine(string.Format("WriteI2C() exception:{0}", ex.Message));
                return S4FwDefs.ERR_UNKNOWN;
            }
        }

        public override int WrRdSPI(int device, ref byte[] data)
        {
            try
            {
                if (device < 0 || device > S4FwDefs.IQDAC)
                    throw new ApplicationException(
                        string.Format("WrRdSPI() error, invalid device {0}, must be between 0 and {1)",
                                                device, S4FwDefs.IQDAC));
                else if (data.Length == 0)
                    throw new ApplicationException("WrRdSPI() error, 0 bytes of data specified");

                if (_s4hw != null)
                {
                    //byte[] cmd = new byte[3 + data.Length];
                    //cmd[0] = S4Cmd.SPI;
                    //cmd[1] = (byte)device;
                    //cmd[2] = (byte)data.Length;
                    //Array.Copy(data, 0, cmd, 3, data.Length);
                    //return _s4hw.ExecuteCommand(cmd, ref cmd);
                    return 0;
                }
                else
                    throw new ApplicationException("S4 hardware not initialized");
            }
            catch (Exception ex)
            {
                AppendLine(string.Format("WrRdSPI() exception:{0}", ex.Message));
                return S4FwDefs.ERR_UNKNOWN;
            }
        }

        public override int RunCmd(string command, ref string rsp)
        {
            int status = 0;
            try
            {
                if (_s4hw != null)
                {
                    status = _s4hw.ExecuteCommand(command, ref rsp);
                    ParseResponseLines(rsp);
                }
            }
            catch (Exception ex)
            {
                AppendLine(string.Format("RunCmd() exception:{0}", ex.Message));
                status = S4FwDefs.ERR_UNKNOWN;
            }
            return status;
        }

        public override int SetFrequency(double megahertz)
        {
            string cmd = string.Format("freq {0:f0}\n", megahertz*1.0e6);
            string rsp = "";
            return RunCmd(cmd, ref rsp);
        }

        public override int GetFrequency(ref double hertz)
        {
            string cmd = string.Format("freq\n");
            string rsp = "";
            int status = RunCmd(cmd, ref rsp);
            if (status == 0)
            {
                if (rsp.StartsWith("\r>"))
                    rsp = rsp.Substring(2);
                if (rsp.StartsWith(">"))
                    rsp = rsp.Substring(1);
                if (rsp.StartsWith(">"))
                    rsp = rsp.Substring(1);
                string[] args = rsp.Split(new char[] { ' ', '\n' });
                hertz = Convert.ToDouble(args[0]);
            }
            else hertz = 0.0;
            return status;
        }

        public override int SetPower(double dbm)
        {
            string cmd = string.Format("power {0:f1}\n", dbm);
            string rsp = "";
            return RunCmd(cmd, ref rsp);
        }

        public override int GetPower(ref double dbm)
        {
            string cmd = string.Format("power\n");
            string rsp = "";
            int status = RunCmd(cmd, ref rsp);
            if (status == 0)
            {
                if (rsp.StartsWith("\r>"))
                    rsp = rsp.Substring(2);
                if (rsp.StartsWith(">"))
                    rsp = rsp.Substring(1);
                if (rsp.StartsWith(">"))
                    rsp = rsp.Substring(1);
                string[] args = rsp.Split(new char[] { ' ', '\n' });
                dbm = Convert.ToDouble(args[0]);
            }
            else dbm = 0.0;
            return status;
        }

        public override int SetCalPower(double dbm)
        {
            // Convert dB into dac value & send it
            // dB is relative to dac 0x80(128) (from M2 anyway)
            // S4 uses attenuation control, so 4095-value gets sent to dac
            double value = dbm / 20.0;
            value = Math.Pow(10.0, value);
            value = value * 128.0 + 0.5;
            ushort vmag = (ushort)(4095 - (int)value);
            string cmd = string.Format("fw 0xf 0x{0:2x} 0x{1:2x} 0x17 0\n", (vmag&0xf)<<4, (vmag&0xff0)>>4);
            string rsp = "";
            return RunCmd(cmd, ref rsp);
        }

        public override int LastProgrammedDb(ref double db)
        {
            return GetPower(ref db);
        }

        public override int ZMonPower(ref double forward, ref double reflected)
        {
            byte[] cmd = new byte[1];
            cmd[0] = S4Cmd.RF_POWER;
            byte[] rsp = null;
            int status = RunCmd(cmd, ref rsp);
            if (status == 0 && rsp.Length >= 8)
            {
                forward = ((rsp[5] << 8) | rsp[4]) / 256.0;
                reflected = ((rsp[7] << 8) | rsp[6]) / 256.0;
            }
            return status;
        }

        public override string ErrorDescription(int errorCode)
        {
            if (_s4hw != null)
                return _s4hw.ErrorDescription(errorCode);
            else return "Error, S4 hardware not defined";
        }

        /// <summary>
        /// Read tags from the system & contruct the present settings
        /// </summary>
        /// <param name="settings"></param>
        /// <returns></returns>
        public override int GetState(ref RfSettings settings)
        {
            double value = 0.0;
            int status = GetFrequency(ref value);
            settings.Frequency = value;

            System.Threading.Thread.Sleep(150); // not too fast
            status |= GetPower(ref value);
            settings.Power = value;

            //if (GetTag("ADLY", ref value) != 0)
                settings.AdcDelayUs = 50;   // Tag not found, use default
            //else settings.AdcDelayUs = (ushort)((ushort)value[0] |
            //                            (((ushort)value[1]) << 8));

            //if (GetTag("CPWR", ref value) != 0)
            //    settings.PwrInDb = 0.0;
            //else
            //    settings.PwrInDb = (double)((UInt32)value[0] |
            //                            (((UInt32)value[1]) << 8)) / 256.0;
            return status;
        }

        ///// <summary>
        ///// Return PA status info
        ///// </summary>
        ///// <param name="status"></param>
        ///// <returns></returns>
        public override int PaStatus(int couplerMode, ref MonitorPa[] results)
        {
            results = new MonitorPa[S4FwDefs.CHANNELS];
            string cmd = "status\n";
            string data = "";
            int status = RunCmd(cmd, ref data);
            if (status == 0)
            {
                results[0].Temperature = 22.5;
                results[0].Voltage = 31.8;
                results[0].Current = 72.5;
                results[0].IDrv = 0.258;
            }
            else results[0].ErrorMessage = string.Format(" status cmd failed:{0}", ErrorDescription(status));

            //// Coupler power
            //double fwd, refl;
            //fwd = refl = 0.0;
            //status = CouplerPower(couplerMode, ref fwd, ref refl);
            //if (status == 0)
            //{
            //    for (channel = 1; channel <= S4FwDefs.CHANNELS; ++channel)
            //    {
            //        results[channel - 1].Forward = fwd;
            //        results[channel - 1].Reflected = refl;
            //    }
            //}
            //else
            //    results[0].ErrorMessage = string.Format(" Read coupler failed:{0}", ErrorDescription(status));
            return status;
        }

        public void AppendLine(string line)
        {
            var now = DateTime.Now;
            var timestamp = string.Format("{0:d02}_{1:d02}_{2:d02}_{3:d02}_{4:d02}_{5:d02}.{6:d03}:",
                                            now.Month, now.Day, now.Year,
                                            now.Hour, now.Minute, now.Second,
                                            now.Millisecond);

            if (!line.EndsWith("\r\n") && !line.EndsWith("\n"))
                line += "\r\n";

            string text = timestamp + line;
            ShowMessage?.Invoke(text);

            StreamWriter fLog = null;
            try
            {
                fLog = new StreamWriter(logFile, true);
                if (fLog != null)
                {
                    fLog.Write(timestamp + line);
                    fLog.Close();
                }
            }
            catch (Exception ex)
            {
                // Can't write to the file, last resort...
                Debug.WriteLine("AppendLine() exception:{0}", ex.Message);
            }
            finally
            {
                if (fLog != null) fLog.Close();
            }
        }

        public override int HiresMode(bool frequencyHiresMode)
        {
            byte[] cmd = new byte[2];
            cmd[0] = S4Cmd.ENABLE_WR;
            cmd[1] = (byte)(0x0f | (frequencyHiresMode ? 0x80 : 0));
            byte[] rsp = null;
            return RunCmd(cmd, ref rsp);
        }

        public override int DutyCycleCompensation(bool enable)
        {
            byte[] cmd = new byte[2];
            cmd[0] = S4Cmd.COMP_DC;
            cmd[1] = (byte)(enable ? 1 : 0);
            byte[] rsp = null;
            return RunCmd(cmd, ref rsp);
        }

        public override int TemperatureCompensation(int mode)
        {
            byte[] cmd = new byte[2];
            cmd[0] = S4Cmd.COMP_TEMP;
            cmd[1] = (byte)mode;
            byte[] rsp = null;
            return RunCmd(cmd, ref rsp);
        }
    }
}
