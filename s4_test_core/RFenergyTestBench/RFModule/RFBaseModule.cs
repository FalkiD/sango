/*
 * Base class for all RF modules, M2, X7, S4, MMC, etc.
 */
using System;
using System.Collections.Generic;
using Interfaces;

namespace RFModule
{
    public class RFBaseModule : IErrors, IDebugging, ICommands
    {
        protected string logFile;

        public MessageCallback ShowMessage;
        event MessageCallback ICommands.ShowMessage
        {
            add     { ShowMessage = value; }
            remove  { ShowMessage = null;  }
        }

        public virtual string HardwareInfo(ref bool demoMode, ref bool hiresMode)
        {
            throw new NotImplementedException();
        }

        public virtual string FirmwareVersion
        {
            get { throw new NotImplementedException(); }
        }

        public virtual string FPGAversion
        {
            get
            {
                throw new NotImplementedException();
            }
        }

        public virtual bool LoopReadings
        {
            get
            {
                throw new NotImplementedException();
            }

            set
            {
                throw new NotImplementedException();
            }
        }

        public virtual int LoopDelayMs
        {
            get
            {
                throw new NotImplementedException();
            }

            set
            {
                throw new NotImplementedException();
            }
        }

        public virtual string Status
        {
            get
            {
                throw new NotImplementedException();
            }
        }

        public virtual int PaChannels
        {
            get { return 1; }
        }

        /// <summary>
        /// On success, returns 0, device has been opened.
        /// </summary>
        /// <param name="logFile"></param>
        /// <returns></returns>
        public virtual int Initialize(string logFile)
        {
            int status = 0;
            CalibrationOn = false;
            this.logFile = logFile;
            Results = new List<string>();
            ShowMessage?.Invoke("Testing");
            return status;
        }

        public virtual void Close()
        {
            throw new NotImplementedException();
        }

        public virtual string ErrorDescription(int errorCode)
        {
            throw new NotImplementedException();
        }

        public virtual int SetTag(string name, string value)
        {
            throw new NotImplementedException();
        }

        public virtual int SetTag(string name, byte[] value)
        {
            throw new NotImplementedException();
        }

        public virtual int GetTag(string name, ref string value)
        {
            throw new NotImplementedException();
        }

        public virtual int GetTag(string name, ref byte[] value)
        {
            throw new NotImplementedException();
        }

        public virtual int WriteEeprom(int offset, byte[] data)
        {
            throw new NotImplementedException();
        }

        public virtual int ReadEeprom(int offset, ref byte[] data)
        {
            throw new NotImplementedException();
        }

        public virtual int WriteI2C(int bus, int address, byte[] data)
        {
            throw new NotImplementedException();
        }

        public virtual int ReadI2C(int channel, int address, byte[] wrbytes, byte[] data)
        {
            throw new NotImplementedException();
        }

        public virtual int WrRdSPI(int device, ref byte[] data)
        {
            throw new NotImplementedException();
        }

        public virtual int RunCmd(byte[] command)
        {
            throw new NotImplementedException();
        }

        public virtual int RunCmd(string command)
        {
            throw new NotImplementedException();
        }

        public virtual int RunCmd(byte[] command, ref byte[] response)
        {
            throw new NotImplementedException();
        }

        public virtual int RunCmd(string command, ref string response)
        {
            throw new NotImplementedException();
        }

        List<string> _formattedResults;
        public virtual List<string> Results
        {
            get { return _formattedResults; }
            set { _formattedResults = value; }
        }


        public virtual int SetFrequency(double hertz)
        {
            throw new NotImplementedException();
        }

        public virtual int GetFrequency(ref double hertz)
        {
            throw new NotImplementedException();
        }

        public virtual int SetPower(double dbm)
        {
            throw new NotImplementedException();
        }
        public virtual int GetPower(ref double dbm)
        {
            throw new NotImplementedException();
        }

        public virtual int LastProgrammedDb(ref double db)
        {
            throw new NotImplementedException();
        }

        public virtual int CouplerPower(int type, ref double forward, ref double reflected)
        {
            throw new NotImplementedException();
        }

        public virtual int ZMonPower(ref double forward, ref double reflected)
        {
            throw new NotImplementedException();
        }

        public virtual int SetPwm(int duty, int rateHz, bool on, bool external)
        {
            throw new NotImplementedException();
        }

        public virtual int PaStatus(int couplerMode, ref MonitorPa[] results)
        {
            throw new NotImplementedException();
        }

        bool _calibration;
        public virtual bool CalibrationOn
        {
            get { return _calibration; }
            set { _calibration = value; }
        }

        public virtual int GetState(ref RfSettings settings)
        {
            throw new NotImplementedException();
        }

        public virtual int HiresMode(bool frequencyHiresMode)
        {
            throw new NotImplementedException();
        }

        public virtual int DutyCycleCompensation(bool enable)
        {
            throw new NotImplementedException();
        }

        public virtual int TemperatureCompensation(int mode)
        {
            throw new NotImplementedException();
        }

        // Appends each line to Results property
        protected virtual void ParseResponseLines(string response)
        {
            Results.Clear();
            string[] lines = response.Split(new char[] { '\n' });
            foreach (string line in lines)
            {
                string next = line.Trim();
                Results.Add(next);
            }
        }

        /// <summary>
        /// I2C Address of 4-channel MCP4728 dac
        /// </summary>
        public virtual int Mcp4728Address
        {
            get { return 0x60; }
            set { int num = value; }
        }

        /// <summary>
        /// I2C address of single-channel MCP4726 dac
        /// </summary>
        public virtual int Mcp4726Address
        {
            get { return 0x61; }
            set { int num = value; }
        }

        /// <summary>
        /// 4 channel MCP4728 dac volts per lsb
        /// </summary>
        public virtual double Mcp4728VoltsPerLsb
        {
            get { return 0.001; }
            set { double tmp = value; }
        }

        /// <summary>
        /// Single channel MCP4726 dac volts per lsb
        /// </summary>
        public virtual double Mcp4726VoltsPerLsb
        {
            get { return 0.001; }
            set { double tmp = value; }
        }

        /// <summary>
        /// Type of instrument
        /// </summary>
        public virtual InstrumentInfo.InstrumentType HwType
        {
            get { return InstrumentInfo.InstrumentType.General; }
        }
    }
}
