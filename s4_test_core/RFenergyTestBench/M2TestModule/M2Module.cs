/*
 * Top level module for M2 hardware testing.
 * Provides public static method for other modules to access
 * the calling assemnbly's ShowMessage delegate to show
 * status messages.
 * 
 * If the delegate is null the messages still go into the log file.
 */
 using System;
using Interfaces;
using RFModule;
using System.IO;
using System.Diagnostics;
using System.Text;

namespace M2TestModule
{
    public class M2Module : RFBaseModule, IErrors, IDebugging, ICommands
    {
        public static M2Module TopModule { get; set; }
        public static void WriteMessage(string message)
        {
            if(TopModule != null)
                TopModule.AppendLine(message);
        }

        Hardware _m2hw = null;
        //MeterCal _meterCal = null;

        /// <summary>
        /// On success, returns 0, M2 device has been opened.
        /// </summary>
        /// <param name="logFile"></param>
        /// <returns></returns>
        public override int Initialize(string logFile)
        {
            base.Initialize(logFile);
            int status = 0;
            this.logFile = logFile;
            TopModule = this;
            _m2hw = new Hardware();
            if (_m2hw != null)
                status = _m2hw.StartupHardware(logFile);
            //if(status == 0)
            //{
            //    _meterCal = new MeterCal();
            //    _meterCal.Initialize(this, this);
            //}

            return status;
        }

        public override InstrumentInfo.InstrumentType HwType
        {
            get { return InstrumentInfo.InstrumentType.M2; }
        }

        public override int PaChannels
        {
            get { return 4; }
        }

        public override void Close()
        {
            if (_m2hw != null)
            {
                _m2hw.Close();
                _m2hw = null;
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

        public override string Status
        {
            get
            {
                throw new NotImplementedException();
            }
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
                if(_m2hw != null)
                {
                    byte[] nam_bytes = Encoding.ASCII.GetBytes(name);
                    int offset = binary ? 3 : 2;
                    byte[] cmd = new byte[1 + name.Length + offset + value.Length];
                    cmd[0] = M2Cmd.SET_TAG;
                    Array.Copy(nam_bytes, 0, cmd, 1, name.Length);
                    if(binary)
                    {
                        cmd[name.Length + 1] = 0x23;
                        cmd[name.Length + 2] = (byte)value.Length;
                    }
                    else
                        cmd[name.Length + 1] = 0x3d;
                    Array.Copy(value, 0, cmd, name.Length + offset, value.Length);
                    return _m2hw.ExecuteCommand(cmd, ref response);
                }
                throw new ApplicationException("M2 hardware not initialized");
            }
            catch(Exception ex)
            {
                AppendLine(string.Format("SetTag() exception:{0}", ex.Message));
                return M2FwDefs.ERR_UNKNOWN;
            }
        }

        public override int GetTag(string name, ref string value)
        {
            try
            {
                if (_m2hw != null)
                {
                    byte[] data = null;
                    int status = GetTag(name, ref data);
                    if(status == 0)
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
                    throw new ApplicationException("M2 hardware not initialized");
            }
            catch (Exception ex)
            {
                AppendLine(string.Format("GetTag() exception:{0}", ex.Message));
                return M2FwDefs.ERR_UNKNOWN;
            }
        }

        public override int GetTag(string name, ref byte[] value)
        {
            try
            {
                if (_m2hw != null)
                {
                    byte[] nam_bytes = Encoding.ASCII.GetBytes(name);
                    byte[] cmd = new byte[name.Length + 2];
                    cmd[0] = M2Cmd.GET_TAG;
                    Array.Copy(nam_bytes, 0, cmd, 1, name.Length);
                    cmd[name.Length + 1] = 0;
                    return _m2hw.ExecuteCommand(cmd, ref value);
                }
                else
                    throw new ApplicationException("M2 hardware not initialized");
            }
            catch (Exception ex)
            {
                AppendLine(string.Format("GetTag() exception:{0}", ex.Message));
                return M2FwDefs.ERR_UNKNOWN;
            }
        }

        public override int ReadEeprom(int offset, ref byte[] data)
        {
            try
            {
                if (_m2hw != null)
                {
                    byte[] cmd = new byte[3];
                    cmd[0] = M2Cmd.RD_EEPROM;
                    cmd[1] = (byte)offset;
                    cmd[2] = (byte)((offset >> 8) & 0xff);
                    return _m2hw.ExecuteCommand(cmd, ref data);
                }
                else
                    throw new ApplicationException("M2 hardware not initialized");
            }
            catch (Exception ex)
            {
                AppendLine(string.Format("GetTag() exception:{0}", ex.Message));
                return M2FwDefs.ERR_UNKNOWN;
            }
        }

        public override int ReadI2C(int channel, int address, byte[] wrbytes, byte[] data)
        {
            try
            {
                if (channel < 0 || channel > 4)
                    throw new ApplicationException(string.Format("ReadI2C error, invalid M2 channel {0}, must be between 0 and 4", channel));

                if (_m2hw != null)
                {
                    byte wr_len = wrbytes == null || wrbytes.Length == 0 ? (byte)0 : (byte)wrbytes.Length;
                    byte[] cmd = new byte[5 + wr_len];
                    cmd[0] = M2Cmd.I2C_RD;
                    cmd[1] = (byte)channel;
                    cmd[2] = (byte)address;
                    cmd[3] = (byte)data.Length;
                    cmd[4] = wr_len;
                    if (wr_len > 0)
                        Array.Copy(wrbytes, 0, cmd, 5, wr_len);
                    byte[] rsp = null;
                    int status = _m2hw.ExecuteCommand(cmd, ref rsp);
                    if (status == 0)
                        Array.Copy(rsp, data, data.Length);
                    return status;
                }
                else
                    throw new ApplicationException("M2 hardware not initialized");
            }
            catch (Exception ex)
            {
                AppendLine(string.Format("ReadI2C() exception:{0}", ex.Message));
                return M2FwDefs.ERR_UNKNOWN;
            }
        }

        public override int WriteEeprom(int offset, byte[] data)
        {
            try
            {
                if (_m2hw != null)
                {
                    byte[] cmd = new byte[3 + data.Length];
                    cmd[0] = M2Cmd.WR_EEPROM;
                    cmd[1] = (byte)offset;
                    cmd[2] = (byte)((offset >> 8) & 0xff);
                    Array.Copy(data, 0, cmd, 3, data.Length);
                    byte[] rsp = null;
                    return _m2hw.ExecuteCommand(cmd, ref rsp);
                }
                else
                    throw new ApplicationException("M2 hardware not initialized");
            }
            catch (Exception ex)
            {
                AppendLine(string.Format("WriteEEPROM() exception:{0}", ex.Message));
                return M2FwDefs.ERR_UNKNOWN;
            }
        }

        public override int WriteI2C(int channel, int address, byte[] data)
        {
            try
            {
                if (channel < 0 || channel > 4)
                    throw new ApplicationException(string.Format("WriteI2C error, invalid M2 channel {0}, must be between 0 and 4", channel));

                if (_m2hw != null)
                {
                    byte[] cmd = new byte[4 + data.Length];
                    cmd[0] = M2Cmd.I2C_WR;
                    cmd[1] = (byte)channel;
                    cmd[2] = (byte)address;
                    cmd[3] = (byte)data.Length;
                    Array.Copy(data, 0, cmd, 4, data.Length);
                    byte[] rsp = null;
                    return _m2hw.ExecuteCommand(cmd, ref rsp);
                }
                else
                    throw new ApplicationException("M2 hardware not initialized");
            }
            catch (Exception ex)
            {
                AppendLine(string.Format("WriteI2C() exception:{0}", ex.Message));
                return M2FwDefs.ERR_UNKNOWN;
            }
        }

        public override int WrRdSPI(int device, ref byte[] data)
        {
            try
            {
                if (device < 0 || device > M2FwDefs.IQDAC)
                    throw new ApplicationException(
                        string.Format("WrRdSPI() error, invalid device {0}, must be between 0 and {1)", 
                                                device, M2FwDefs.IQDAC));
                else if (data.Length == 0)
                    throw new ApplicationException("WrRdSPI() error, 0 bytes of data specified");

                if (_m2hw != null)
                {
                    byte[] cmd = new byte[3 + data.Length];
                    cmd[0] = M2Cmd.SPI;
                    cmd[1] = (byte)device;
                    cmd[2] = (byte)data.Length;
                    Array.Copy(data, 0, cmd, 3, data.Length);
                    return _m2hw.ExecuteCommand(cmd, ref cmd);
                }
                else
                    throw new ApplicationException("M2 hardware not initialized");
            }
            catch (Exception ex)
            {
                AppendLine(string.Format("WrRdSPI() exception:{0}", ex.Message));
                return M2FwDefs.ERR_UNKNOWN;
            }
        }

        public override int RunCmd(byte[] command, ref byte[] rsp)
        {
            try
            {
                if (_m2hw != null)
                {
                    return _m2hw.ExecuteCommand(command, ref rsp);
                }
                throw new ApplicationException("M2 hardware not initialized");
            }
            catch (Exception ex)
            {
                AppendLine(string.Format("RunCmd() exception:{0}", ex.Message));
                return M2FwDefs.ERR_UNKNOWN;
            }
        }

        public override int RunCmd(string command, ref string rsp)
        {
            int status = 0;
            try
            {
                if (_m2hw != null)
                {
                    string[] strBytes = command.Split(new char[] { ' ', ',' });
                    byte[] data = null;
                    byte[] cmd = new byte[512];
                    for (var k = 0; k < strBytes.Length; ++k)
                        cmd[k] = Convert.ToByte(strBytes[k], 16);
                    status = _m2hw.ExecuteCommand(cmd, ref data);
                    Results.Clear();
                    if (status == 0)
                    {
                        Results.Add(string.Format("RunCmd 0x{0} Ok\n", strBytes[0]));
                        Results.Add(string.Format("  {0:x02} {1:x02} {2:x02} {3:x02} {4:x02} {5:x02} {6:x02} {7:x02}",
                                                    data[0], data[1], data[2], data[3], data[4], data[5], data[6], data[7]));
                        if (data.Length >= 16)
                            Results.Add(string.Format("  {0:x02} {1:x02} {2:x02} {3:x02} {4:x02} {5:x02} {6:x02} {7:x02}",
                                        data[8], data[9], data[10], data[11], data[12], data[13], data[14], data[15]));
                    }
                }
            }
            catch (Exception ex)
            {
                AppendLine(string.Format("RunCmd() exception:{0}", ex.Message));
                status = M2FwDefs.ERR_UNKNOWN;
            }
            return status;
        }

        public override int SetFrequency(double hertz)
        {
            int frq = (int)(hertz * 65536.0);     // Q15.16 format
            byte[] cmd = null;
            cmd = new byte[5];
            cmd[0] = M2Cmd.FREQ;
            cmd[1] = (byte)(frq & 0xff);
            cmd[2] = (byte)((frq >> 8) & 0xff);
            cmd[3] = (byte)((frq >> 16) & 0xff);
            cmd[4] = (byte)((frq >> 24) & 0xff);
            //else if (MainViewModel.SelectedSystemName.StartsWith("MMC"))
            //{
            //    status = MainViewModel.IOpcodes.FrequencyOpcode(Frequency * 1.0e6, ref cmd);
            //}
            byte[] rsp = null;
            return RunCmd(cmd, ref rsp);
        }

        public override int SetPower(double dbm)
        {
            int pwr = (int)((dbm+0.05) * 256.0);     // Q7.8 format
            byte[] cmd = new byte[3];
            cmd[0] = M2Cmd.POWER;
            cmd[1] = (byte)(pwr & 0xff);
            cmd[2] = (byte)((pwr >> 8) & 0xff);
            byte[] rsp = null;
            return RunCmd(cmd, ref rsp);
        }

        public override int GetPower(ref double dbm)
        {
            string cmd = string.Format("power\n");
            string rsp = "";
            int status = RunCmd(cmd, ref rsp);
            if (status == 0)
            {
                string[] args = rsp.Split(new char[] { ' ', '\n' });
                dbm = Convert.ToDouble(args[0]);
            }
            else dbm = 0.0;
            return status;
        }

        public override int LastProgrammedDb(ref double db)
        {
            byte[] cmd = new byte[1];
            cmd[0] = M2Cmd.LASTDB;
            byte[] data = null;
            int status = RunCmd(cmd, ref data);
            if (status == 0 && data != null)
            {
                db = (double)((int)data[0] | ((int)data[1] << 8)) / 256.0;
            }
            return status;
        }

        public override int CouplerPower(int type, ref double forward, ref double reflected)
        {
            byte[] cmd = new byte[2];
            cmd[0] = M2Cmd.RF_POWER;
            cmd[1] = (byte)type;
            byte[] rsp = null;
            int status = RunCmd(cmd, ref rsp);
            if(status == 0 && rsp.Length >= 8)
            {
                int tmp = ((rsp[1] << 8) | rsp[0]);
                if(type != M2Cmd.PWR_DBM)
                {
                    //if ((tmp & 0x2000) != 0)
                    //    unchecked { tmp |= (int)0xfffffc00; }
                    forward = tmp;
                    tmp = ((rsp[3] << 8) | rsp[2]);
                    //if ((tmp & 0x2000) != 0)
                    //    unchecked { tmp |= (int)0xfffffc00; }
                    reflected = tmp;
                }
                else
                {
                    forward = tmp / 256.0;
                    tmp = ((rsp[3] << 8) | rsp[2]);
                    reflected = tmp / 256.0;
                }
            }
            return status;
        }

        public override int ZMonPower(ref double forward, ref double reflected)
        {
            byte[] cmd = new byte[1];
            cmd[0] = M2Cmd.RF_POWER;
            byte[] rsp = null;
            int status = RunCmd(cmd, ref rsp);
            if (status == 0 && rsp.Length >= 8)
            {
                forward = ((rsp[5] << 8) | rsp[4]) / 256.0;
                reflected = ((rsp[7] << 8) | rsp[6]) / 256.0;
            }
            return status;
        }

        public override int SetPwm(int duty, int rateHz, bool on, bool external)
        {
            byte[] cmd = new byte[5];
            cmd[0] = M2Cmd.PWM;
            if(on == false)
            {
                cmd[1] = cmd[2] = 0;    // CW=0 & Duty=0 turns PWM OFF
            }
            else if (external)
            {
                cmd[1] = 0x02;
            }
            else
            {
                if (duty >= 100)
                {
                    if (duty > 100)
                        duty = 100;
                    if (duty == 100)
                        cmd[1] = 0x01;
                    else cmd[1] = 0;
                }
                cmd[2] = (byte)duty;
                if (rateHz > 65000)
                    rateHz = 65000;
                else if (rateHz < 1)
                    rateHz = 1;
                cmd[3] = (byte)(rateHz & 0xff);
                cmd[4] = (byte)((rateHz >> 8) & 0xff);
            }
            byte[] rsp = null;
            return RunCmd(cmd, ref rsp);
        }


        public override string ErrorDescription(int errorCode)
        {
            if (_m2hw != null)
                return _m2hw.ErrorDescription(errorCode);
            else return "Error, M2 hardware not defined";
        }

        /// <summary>
        /// Read tags from the system & contruct the present settings
        /// </summary>
        /// <param name="settings"></param>
        /// <returns></returns>
        public override int GetState(ref RfSettings settings)
        {
            byte[] value = new byte[16];
            int status = GetTag("FRQ", ref value);
            settings.Frequency = (double)((UInt32)value[0] |
                                (((UInt32)value[1]) << 8) |
                                (((UInt32)value[2]) << 16) |
                                (((UInt32)value[3]) << 24)) / 65536.0; 

            status |= GetTag("PWR", ref value);
            settings.Power = (double)((UInt32)value[0] |
                             (((UInt32)value[1]) << 8)) / 256.0;

            //status = GetTag("PHS", ref value);
            status |= GetTag("PWM", ref value);
            settings.PwmDutyCycle = value[1];
            settings.PwmRateHz = value[2] | ((value[3] & 0xff) << 8);

            if (GetTag("ADLY", ref value) != 0)
                settings.AdcDelayUs = 90;   // Tag not found, use default
            else settings.AdcDelayUs = (ushort)((ushort)value[0] |
                                        (((ushort)value[1]) << 8));

            if (GetTag("CPWR", ref value) != 0)
                settings.PwrInDb = 0.0;
            else
                settings.PwrInDb = (double)((UInt32)value[0] |
                                        (((UInt32)value[1]) << 8)) / 256.0;
            return status;
        }

        ///// <summary>
        ///// Return PA status info
        ///// </summary>
        ///// <param name="status"></param>
        ///// <returns></returns>
        public override int PaStatus(int couplerMode, ref MonitorPa[] results)
        {
            results = new MonitorPa[M2FwDefs.CHANNELS];
            int channel = -1;
            byte[] cmd = new byte[1];
            cmd[0] = M2Cmd.RF_STATUS;
            byte[] data = null;
            int status = RunCmd(cmd, ref data);
            if (status == 0)
            {
                if (data != null)
                {
                    for (channel = 1; channel <= M2FwDefs.CHANNELS; ++channel)
                    {
                        int offset = 1 + 6 * (channel - 1);
                        int value = (data[offset + 1] << 8) | data[offset];
                        if ((value & 0x8000) != 0)
                            unchecked { value |= (int)0xffff0000; }
                        results[channel-1].Temperature = value / 256.0;

                        value = ((data[offset + 3] << 8) | data[offset + 2]);
                        results[channel - 1].Voltage = (double)value / 256.0;

                        value = (data[offset + 5] << 8) | data[offset + 4];
                        results[channel - 1].Current = value / 256.0;
                    }
                }
                else results[0].ErrorMessage = " RF_STATUS returned no data, is M2 online?";
            }
            else results[0].ErrorMessage = string.Format(" RF_STATUS failed:{0}", ErrorDescription(status));

            // Get IDRV too
            cmd[0] = M2Cmd.IDRV;
            status = RunCmd(cmd, ref data);
            if (status == 0)
            {
                if (data != null)
                {
                    for (channel = 1; channel <= M2FwDefs.CHANNELS; ++channel)
                    {
                        int offset = 2 * (channel - 1);
                        results[channel - 1].IDrv = (double)((data[offset + 1] << 8) | data[offset]) / 256.0;
                    }
                }
                else results[0].ErrorMessage = " IDRV returned no data, is M2 online?";
            }
            else results[0].ErrorMessage = string.Format(" IDRV failed:{0}", ErrorDescription(status));

            // Coupler power
            double fwd, refl;
            fwd = refl = 0.0;
            status = CouplerPower(couplerMode, ref fwd, ref refl);
            if (status == 0)
            {
                for (channel = 1; channel <= M2FwDefs.CHANNELS; ++channel)
                {
                    results[channel - 1].Forward = fwd;
                    results[channel - 1].Reflected = refl;
                }
            }
            else
                results[0].ErrorMessage = string.Format(" Read coupler failed:{0}", ErrorDescription(status));
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
            cmd[0] = M2Cmd.ENABLE_WR;
            cmd[1] = (byte)(0x0f | (frequencyHiresMode ? 0x80 : 0));
            byte[] rsp = null;
            return RunCmd(cmd, ref rsp);
        }

        public override int DutyCycleCompensation(bool enable)
        {
            byte[] cmd = new byte[2];
            cmd[0] = M2Cmd.COMP_DC;
            cmd[1] = (byte)(enable ? 1 : 0);
            byte[] rsp = null;
            return RunCmd(cmd, ref rsp);
        }

        public override int TemperatureCompensation(int mode)
        {
            byte[] cmd = new byte[2];
            cmd[0] = M2Cmd.COMP_TEMP;
            cmd[1] = (byte)mode;
            byte[] rsp = null;
            return RunCmd(cmd, ref rsp);
        }
    }
}

// ZMon/Power cal routines from ctrl4_xdif fw
//ZmonCal_t ZmonCal[TGT_MW_CHANS_MAX] @ "EXRAM2";

//#ifndef USE_ZMON_BUFFER
//ZmonOutput_t ZmonOut[TGT_MW_CHANS_MAX];
//#else
////4 channel FI/Fq RI/RQ and F/R powerresults
//ZmonOutput_t ZmonOut[TGT_MW_CHANS_MAX][ZMON_BUFF_SIZE] @ "EXRAM2";
//int ZmonBufInIndex, ZmonBufOutIndex @ "EXRAM2";
//#endif

//PmonCal_t PmonCal[TGT_MW_CHANS_MAX] @ "EXRAM2";
//#ifndef USE_PMON_BUFFER
//PmonOutput_t PmonOut[TGT_MW_CHANS_MAX];
//#else
////4 channel cal array
////4 channel FI/Fq RI/RQ and F/R powerresults
////PmonOutput_t PmonOut[TGT_MW_CHANS_MAX][PMON_BUFF_SIZE] @ "EXRAM2";
////int PmonBufInIndex, PmonBufOutIndex @ "EXRAM2";
//#endif

////temperature, fan flow, h2o flow measurements
//SysStatus_t SysStatus;
////control and limits data
//BGConfig_t BGConfig;

//uint32 PmonSampleDelay[TGT_MW_CHANS_MAX];
//uint8 PmonTriggerChan, ZmonTriggerReady;
//bool PmonTriggerReady;


//// get numeric value from tag
//void get_ZorP_cal_val( const char* locStr, float* Fresult, int* Iresult)
//{
//    char* locPtr;
//    int len;

//    if (find_tag((char*)locStr, 0, &locPtr, &len))
//    {
//        locPtr = strchr((const char*)locPtr, '=' ) +1;
//        if (strchr((const void*)locStr, 'O' ) )
//      *Iresult = (atoi((const char*)locPtr ) ); 
//    else
//      *Fresult = (atof((const char*)locPtr ) );

//    }
//    else
//    {
//        if (strchr((const void*)locStr, 'O' ) )
//      *Iresult = 0.0;
//    else
//      *Fresult = 1.0;
//    }

//}

//// get numeric value from tag
//void get_P_cal_val( const char* locStr, float* Fresult, int* Iresult)
//{
//    char* locPtr;
//    int len;

//    if (find_tag((char*)locStr, 0, &locPtr, &len))
//    {
//        locPtr = strchr((const char*)locPtr, '=' ) +1;
//        *Fresult = (atof((const char*)locPtr ) );

//    }
//    else
//    {
//        if (strchr((const void*)locStr, 'O' ) )
//      *Fresult = -3400.0;
//    else
//      *Fresult = 2.3;
//    }

//}

////set working cal values
////fill zmon struct from tagged memory on powerup      
//void set_ZC_cal_values()
//{
//    int i, j = 0;

//    for (i = 0; i < 4; i++)
//    {
//        get_ZorP_cal_val(ZCalTagNames[j++], NULL, &ZmonCal[i].FwdIOffset);
//        get_ZorP_cal_val(ZCalTagNames[j++], &ZmonCal[i].FwdIGain, NULL);
//        get_ZorP_cal_val(ZCalTagNames[j++], NULL, &ZmonCal[i].FwdQOffset);
//        get_ZorP_cal_val(ZCalTagNames[j++], &ZmonCal[i].FwdQGain, NULL);
//        get_ZorP_cal_val(ZCalTagNames[j++], NULL, &ZmonCal[i].RevIOffset);
//        get_ZorP_cal_val(ZCalTagNames[j++], &ZmonCal[i].RevIGain, NULL);
//        get_ZorP_cal_val(ZCalTagNames[j++], NULL, &ZmonCal[i].RevQOffset);
//        get_ZorP_cal_val(ZCalTagNames[j++], &ZmonCal[i].RevQGain, NULL);
//    }
//}

////set working cal values
////set single ZM cal value in RAM      
//unsigned long set_ZM_tmp_cal(int argc, unsigned char** argv)
//{
//    int chan;
//    double value;

//    if (argc == 3)
//    {
//        if (!cmd_atoi(argv[1], &chan))
//        {
//            printf("Bad channel\r\n");
//            return (CMD_FALSE);
//        }
//        else
//        {
//            value = atof((const char*)argv[3]);
//            chan--;

//            if (strstr((const char*)argv[2], "AIO") != NULL )
//        ZmonCal[chan].FwdIOffset = (int)value;
//      else if (strstr((const char*)argv[2], "AIG") != NULL )
//        ZmonCal[chan].FwdIGain = (float)value;
//      else if (strstr((const char*)argv[2], "AQO") != NULL )
//        ZmonCal[chan].FwdQOffset = (int)value;
//      else if (strstr((const char*)argv[2], "AQG") != NULL )
//        ZmonCal[chan].FwdQGain = (float)value;

//      else if (strstr((const char*)argv[2], "BIO") != NULL )
//        ZmonCal[chan].RevIOffset = (int)value;
//      else if (strstr((const char*)argv[2], "BIG") != NULL )
//        ZmonCal[chan].RevIGain = (float)value;
//      else if (strstr((const char*)argv[2], "BQO") != NULL )
//        ZmonCal[chan].RevQOffset = (int)value;
//      else if (strstr((const char*)argv[2], "BQG") != NULL )
//        ZmonCal[chan].RevQGain = (float)value;
//      else
//      {
//                printf("Bad args\r\n");
//                return (CMD_FALSE);
//            }
//            return (CMD_TRUE);
//        }
//    }
//    else if (argc == 1)
//    {
//        if (!cmd_atoi(argv[1], &chan))
//        {
//            printf("Bad channel\r\n");
//            return (CMD_FALSE);
//        }
//        else
//        {
//            chan--;

//            printf("AIO= %d\r\n", ZmonCal[chan].FwdIOffset);
//            printf("AIG= %f\r\n", ZmonCal[chan].FwdIGain);
//            printf("AQO= %d\r\n", ZmonCal[chan].FwdQOffset);
//            printf("AQG= %f\r\n", ZmonCal[chan].FwdQGain);
//            printf("BIO= %d\r\n", ZmonCal[chan].RevIOffset);
//            printf("BIG= %f\r\n", ZmonCal[chan].RevIGain);
//            printf("BQO= %d\r\n", ZmonCal[chan].RevQOffset);
//            printf("BQG= %f\r\n", ZmonCal[chan].RevQGain);

//            return (CMD_TRUE);
//        }
//    }
//    else
//    {
//        printf("Bad channel\r\n");
//        return (CMD_FALSE);
//    }

//}

////fill pmon struct from tagged memory on powerup      
//void set_PC_cal_values()
//{
//    int i, j = 0;

//    for (i = 0; i < 4; i++)
//    {
//        get_P_cal_val(PCalTagNames[j++], &PmonCal[i].PwrAOffset, NULL);
//        get_P_cal_val(PCalTagNames[j++], &PmonCal[i].PwrAGain, NULL);
//        get_P_cal_val(PCalTagNames[j++], &PmonCal[i].PwrBOffset, NULL);
//        get_P_cal_val(PCalTagNames[j++], &PmonCal[i].PwrBGain, NULL);
//    }
//}

////applies zmon calibration to incomming readings
//void apply_zmon_cal(ZmonOutput_t* ZmonOut, int zmon_id, volatile short* dataIn)
//{
//    ZmonOut->ZmonVrms[FI] = ZmonCal[zmon_id].FwdIGain * ((float)(dataIn[FI] - ZmonCal[zmon_id].FwdIOffset));
//    ZmonOut->ZmonVrms[FQ] = ZmonCal[zmon_id].FwdQGain * ((float)(dataIn[FQ] - ZmonCal[zmon_id].FwdQOffset));
//    ZmonOut->ZmonVrms[RI] = ZmonCal[zmon_id].RevIGain * ((float)(dataIn[RI] - ZmonCal[zmon_id].RevIOffset));
//    ZmonOut->ZmonVrms[RQ] = ZmonCal[zmon_id].RevQGain * ((float)(dataIn[RQ] - ZmonCal[zmon_id].RevQOffset));

//    //      ZmonOut->ZmonPwr[FWD] = sqrt(ZmonOut->ZmonVrms[FI]*ZmonOut->ZmonVrms[FI] + ZmonOut->ZmonVrms[FQ]*ZmonOut->ZmonVrms[FQ]) / 50.0;
//    //      ZmonOut->ZmonPwr[REV] = sqrt(ZmonOut->ZmonVrms[RI]*ZmonOut->ZmonVrms[RI] + ZmonOut->ZmonVrms[RQ]*ZmonOut->ZmonVrms[RQ]) / 50.0;          
//}

////applies pmon calibration to incomming readings
//void apply_pmon_cal(PmonOutput_t* PmonOut, int chan, short* dataIn)
//{
//    float workf;

//    if (dataIn[0] < 0)
//        PmonOut->PmonAPwr = 0;
//    else
//    {
//#if 0        
//        workf = (float)(4095 - dataIn[0]);
//        workf /= 0.490;
//        workf = 6000.0 - workf;
//        if ( workf < 0.0 )
//          workf = 0;
//#endif
//        //        workf = (PmonCal[chan].PwrAGain * ( workf - (PmonCal[chan].PwrAOffset*100.0)));
//        workf = (float)dataIn[0];
//        workf = (workf * PmonCal[chan].PwrAGain) + PmonCal[chan].PwrAOffset;
//        if (workf < 0.0)
//            PmonOut->PmonAPwr = 0;
//        else
//            PmonOut->PmonAPwr = (uint16)workf;
//    }

//    if (dataIn[1] < 0)
//        PmonOut->PmonBPwr = 0;
//    else
//    //        PmonOut->PmonBPwr = (uint16)(PmonCal[chan].PwrBGain * (float)( dataIn[1] - PmonCal[chan].PwrBOffset ));
//    {
//#if 0
//        workf = (float)(4095 - dataIn[1]);
//        workf /= 0.490;
//        workf = 6000.0 - workf;
//        if ( workf < 0.0 )
//          workf = 0;
//#endif
//        workf = (float)dataIn[1];
//        //        workf = (PmonCal[chan].PwrBGain * ( workf - (PmonCal[chan].PwrBOffset*100.0)));
//        workf = (workf * PmonCal[chan].PwrBGain) + PmonCal[chan].PwrBOffset;
//        if (workf < 0.0)
//            PmonOut->PmonBPwr = 0;
//        else
//            PmonOut->PmonBPwr = (uint16)workf;
//    }
//}

////converts ADC IN6 counts to int volts  
//void scale_PS_volts(PmonOutput_t* PmonOut, int chan, short* dataIn)
//{
//    int worki;

//    worki = (int)dataIn[0];
//    if (dataIn[0] < 0)
//        PmonOut->PSAVolts = 0;
//    else
//    {
//        worki = (worki * 5000) / 4096;
//        PmonOut->PSAVolts = worki / 10;
//        if ((worki - (PmonOut->PSAVolts * 10)) > 4)
//            PmonOut->PSAVolts++;
//    }
//    worki = (int)dataIn[1];
//    if (dataIn[1] < 0)
//        PmonOut->PSBVolts = 0;
//    else
//    {
//        worki = (worki * 5000) / 4096;
//        PmonOut->PSBVolts = worki / 10;
//        if ((worki - (PmonOut->PSBVolts * 10)) > 4)
//            PmonOut->PSBVolts++;
//    }
//    //        PmonOut->PSBVolts = (worki * 500) / 4096;
//}


