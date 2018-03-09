/*
 * Top level module for S4 hardware testing.
 * Provides public static method for other modules to access
 * the calling assemnbly's ShowMessage delegate to show
 * status messages.
 * 
 */
using System;
using System.Diagnostics;
using System.Text.RegularExpressions;
using Interfaces;
using RFModule;
using System.Collections.Generic;

namespace S4TestModule
{
    public class S4Module : RFBaseModule, IErrors, IDebugging, ICommands
    {
        // Driver EEPROM addresses for 5 ~6.5kbyte json caldata files.
        // spaced at 8192 byte intervals. 64kbyte total space
        const int DRV_ADR_2410 = 1024;
        const int DRV_ADR_2430 = 9216;
        const int DRV_ADR_2450 = 17408;
        const int DRV_ADR_2470 = 25600;
        const int DRV_ADR_2490 = 33792;

        public static S4Module TopModule { get; set; }
        public static void WriteMessage(string message)
        {
            if (TopModule != null)
                TopModule.AppendLine(message);
        }

        S4Hardware _s4hw = null;
        const int HALF_DB_CAL_POINTS = 51;

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

            ProgrammedDb = 0.0;

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

        /// <summary>
        /// Save last programmed db value from SetCalPower command
        /// </summary>
        public double ProgrammedDb { get; set; }

        // methods

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
            try
            {
                if (_s4hw != null)
                {
                    string rsp = "";
                    return RunCmd(string.Format("eepw {0}={1}\n", name, value), ref rsp);
                }
                else
                    throw new ApplicationException("S4 hardware not initialized");
            }
            catch (Exception ex)
            {
                AppendLine(string.Format("SetTag({0},{1}) exception:{2}", name, value, ex.Message));
                return S4FwDefs.ERR_UNKNOWN;
            }
        }

        public override int GetTag(string name, ref string value)
        {
            try
            {
                if (_s4hw != null)
                {
                    string tag = "";
                    int status = RunCmd(string.Format("eepr {0}\n", name), ref tag);
                    if (status == 0)
                        value = tag;
                    else value = string.Format(" Read tag {0} failed:{1}", name, ErrorDescription(status));
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
                        cmd = string.Format("ir pa 0xc2 {0}", data.Length);
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
            int status = RunCmd(cmd, ref rsp);
            if (status == 0)
                FrequencyEvent?.Invoke(megahertz, "FrequencyOk");
            return status;
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
            int status = RunCmd(cmd, ref rsp);
            if (status == 0)
                PowerEvent?.Invoke(dbm, ProgrammedDb, "PowerOk");
            return status;
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

        public override ushort DacFromDB(double db)
        {
            // for S4, dB is relative to dac 0x10(16)
            // S4 uses attenuation control, so 4095-value gets sent to dac
            double value = db / 20.0;
            value = Math.Pow(10.0, value);
            value = value * 16.0 + 0.5;
            return (value > 4095) ? (ushort)0 : (ushort)(4095 - (int)value);
        }

        public override int SetCalPower(double db)
        {
            // Convert dB into dac value & send it
            // Driving both DAC's
            //
            // Save the value to use when updating UI's with event 
            //
            ushort vmag = DacFromDB(db);
            string cmd = string.Format("calpwr 0x0017{0:x2}{1:x2}\n", (vmag & 0xff0) >> 4, (vmag & 0xf) << 4);
            string rsp = "";
            int status = RunCmd(cmd, ref rsp);
            if (status == 0)
            {
                CalDbEvent?.Invoke(db, "CalDbOk");
                ProgrammedDb = db;
            }
            return status;
        }

        public override int LastProgrammedDb(ref double db)
        {
            db = ProgrammedDb;
            CalDbEvent?.Invoke(db, "CalDbOk");
            return 0;
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

        public override bool BiasEnable(bool enable)
        {
            try
            {
                string cmd, rsp = "";
                cmd = enable ? "fw 6 1 1\n" : "fw 6 1 0\n";
                int status = RunCmd(cmd, ref rsp);
                if (status == 0)
                    BiasEvent?.Invoke(enable, "BiasOk");
            }
            catch (Exception ex)
            {
                throw new ApplicationException(string.Format("S4 BIAS Exception:{0}", ex.Message), ex);
            }
            return enable;
        }

        void ShowResults()
        {
            if(Results.Count > 0)
                foreach (string str in Results)
                    WriteMessage(str);
        }

        public override int WriteDriverCalData(double frequency, byte[] jsonData, int address)
        {
            // Write the json file using 64 byte ASCII lines
            int status = 0;
            int addr;
            try
            {
                if (frequency <= 2410.0)
                    addr = DRV_ADR_2410;
                else if (frequency <= 2430.0)
                    addr = DRV_ADR_2430;
                else if (frequency <= 2450.0)
                    addr = DRV_ADR_2450;
                else if (frequency <= 2470.0)
                    addr = DRV_ADR_2470;
                else addr = DRV_ADR_2490;

                const int BYTES_PER_LINE = 64;
                int count = jsonData.Length / BYTES_PER_LINE;
                count += (jsonData.Length % BYTES_PER_LINE > 0 ? 1 : 0);
                int index = 0;
                while(index < jsonData.Length)
                {
                    // d15-d7 must stay the same for each block write, i.e. 128 bytes
                    // at a time(same 'row').
                    string line;
                    if (index == 0)
                        line = string.Format("iw drv 0xA0 {0} {1} {2} ", addr + index, jsonData.Length & 0xff, (jsonData.Length >> 8) & 0xff);
                    else
                        line = string.Format("iw drv 0xA0 {0} ", addr + index);
                    int memory_row = (addr + index) & 0xff80;   // d15-d7 must remain the same to stay on same row
                    for (int j = 0; j < BYTES_PER_LINE; ++j, ++index)
                    {
                        int next_row = (addr + index) & 0xff80;
                        if (next_row != memory_row)
                            break;

                        line += string.Format("{0}{1}", jsonData[index], j < BYTES_PER_LINE-1 ? " " : "");
                    }
                    line += "\n";
                    string rsp = "";
                    if((status = RunCmd(line, ref rsp)) != 0)
                        break;
                }
                if (status == 0)
                    WriteMessage("Done writing S4 driver power table");
                else
                {
                    WriteMessage(string.Format("Error writing S4 driver power table:{0}", status));
                    ShowResults();
                }
            }
            catch (Exception ex)
            {
                WriteMessage(string.Format("Exception writing S4 driver power table:{0}", ex.Message));
            }
            return status;
        }

        public override int WriteCalResults(bool inuse, bool persist, double frequency, List<PowerCalData> results)
        {
            if (results.Count > HALF_DB_CAL_POINTS)
                throw new ApplicationException(string.Format("Too many cal points({0}), maximum is {1}", 
                                                                results.Count, HALF_DB_CAL_POINTS));

            // 01-Nov-2017 update, fw command line is only 256 bytes,
            // break up calpwtbl write into 6 pieces.
            // calpwtbl has 5 45 element records & 1 26 element record
            // calpwtbl rec# freq mode value0 value1 value2...value44

            int status = 0;
            try
            {
                string freq;
                if (frequency <= 2410.0)
                    freq = "2410";
                else if (frequency <= 2430.0)
                    freq = "2430";
                else if (frequency <= 2450.0)
                    freq = "2450";
                else if (frequency <= 2470.0)
                    freq = "2470";
                else freq = "2490";

                int bits = 0;
                if (inuse) bits |= 1;
                if (persist) bits |= 2;
                string update = bits.ToString();

                // Create 251 entries from the 51 entries, put together 5 45 
                // entry data strings and one 26 entry string 
                PowerCalData entry = null;
                string strData = "";
                int rec_size = 45;      // 5 45 entry records & 1 26 entry record
                string cmd;
                for (int recnum = 0; recnum < 6; ++recnum)
                {
                    if (recnum > 4)
                        rec_size = 26;

                    cmd = string.Format("calpwtbl {0} {1} {2}", recnum, freq, update);
                    WriteMessage(string.Format("Writing S4 power table:{0}", cmd));

                    int idx;
                    for (int k = 0; k < rec_size / 5; ++k)
                    {
                        idx = k + recnum * 9;
                        if (idx < results.Count)
                            entry = results[idx];
                        ushort vmag = DacFromDB(entry.PowerDB);
                        strData = string.Format(" {0}", vmag);
                        cmd += strData;
                        // do interpolation here to fill next 4 entries until last entry
                        if (k < rec_size - 1)
                        {
                            double span;
                            if (idx < results.Count - 1)
                                span = results[idx + 1].PowerDB - entry.PowerDB;
                            else
                                span = 0.0;
                            double increment = span / 5.0;
                            for (int j = 1; j <= 4; ++j)
                            {
                                double next = entry.PowerDB + j * increment;
                                vmag = DacFromDB(next);
                                strData = string.Format(" {0}", vmag);
                                cmd += strData;
                            }
                        }
                    }
                    WriteMessage(cmd);
                    cmd += "\n";
                    string rsp = "";
                    System.Threading.Thread.Sleep(250);
                    if ((status = RunCmd(cmd, ref rsp)) != 0)
                        break;
                    ShowResults();
                }
                if (status == 0)
                    WriteMessage("Done writing S4 power table");
                else
                {
                    WriteMessage(string.Format("Error writing S4 power table:{0}", status));
                    ShowResults();
                }
            }
            catch (Exception ex)
            {
                WriteMessage(string.Format("Exception writing S4 power table:{0}", ex.Message));
            }
            return status;
        }

        public override int PersistCalResults(double frequency)
        {
            return 0;   // not needed on S4, handled in WriteCalResults()
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
            string cmd = "tc\n";
            string rsp = "";
            int status = RunCmd(cmd, ref rsp);
            if (status == 0)
            {
                string[] s4_data = rsp.Split(new char[] { '\r', '\n' });
                if(s4_data.Length >= 2)
                {
                    //string pa_temp, drv_temp, pa_i, drv_i;
                    Regex rgx = new Regex("[a-zA-Z ]*:[ ]*([0-9]*)\t\tCurrent[ ]*([0-9]*).([0-9]*)");
                    Match match = rgx.Match(s4_data[0]);
                    if(match.Success)
                    {
                        results[0].Current = Convert.ToDouble(match.Groups[2].Value + "." + match.Groups[3].Value);
                    }

                    // Driver string only has 1 tab???
                    rgx = new Regex("[a-zA-Z ]*:[ ]*([0-9]*)\tCurrent[ ]*([0-9]*).([0-9]*)");
                    match = rgx.Match(s4_data[1]);
                    if (match.Success)
                    {
                        // Driver temperature is higher on the S4
                        results[0].Temperature = Convert.ToDouble(match.Groups[1].Value);
                        results[0].IDrv = Convert.ToDouble(match.Groups[2].Value + "." + match.Groups[3].Value);
                    }
                    return status;
                }
            }
            results[0].ErrorMessage = string.Format(" PaStatus cmd failed:{0}", ErrorDescription(status));

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
            ShowMessage?.Invoke(line);
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
            Debug.WriteLine("*Duty cycle compensation not needed on S4*");
            return 0;
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
