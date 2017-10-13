using System;
using Interfaces;
using LadyBug_TestHarness;
//using NationalInstruments.VisaNS;
using System.Collections.Generic;

namespace ExternalPowerMeter
{
    public class ExternalMeter : IInstrument
    {
        //string _deviceName;
        //GpibSession     _gpib = null;
        //ResourceManager _rm;
        int _sensorCount;
        LB_API2_Declarations.SDByte[] _sensDesc;

        public event MessageCallback ShowMessage;

        const int HEAD_OFFSET_FREQUENCIES = 3;  // 2400, 2450, 2500 for now

        public ExternalMeter()
        {
            HeadOffsets = new double[HEAD_OFFSET_FREQUENCIES];
        }

        public double[] HeadOffsets { get; set; }

        string _id;
        public string ID
        {
            get { return _id; }
            private set { _id = value; }
        }

        public InstrumentInfo.InstrumentType InstrumentType
        {
            get { return InstrumentInfo.InstrumentType.Meter; }
        }

        public InstrumentInfo.Interface Interface
        {
            get { return InstrumentInfo.Interface.USB; }
        }

        List<string> _sensorList = new List<string>();
        public List<string> Names
        {
            get
            {
                //if (_gpib == null)
                //    throw new ApplicationException("GPIB device is null, can't read name");
                //return _gpib.Query("ID?");
                return _sensorList;
            }
        }

        public string Name
        {
            get
            {
                if (_sensorList.Count > 0)
                    return _sensorList[0];
                return "(none)";
            }
        }

        public string Version
        {
            get { return "1.0"; }
        }

        public string Description
        {
            get
            {
                throw new NotImplementedException();
            }
        }

        public bool Online
        {
            get { return false; } //(_gpib != null); }
        }

        bool _triggerInEnable;
        public bool TriggerInEnable
        {
            get { return _triggerInEnable; }
            set
            {
                try
                {
                    LB_API2_Declarations.FEATURE_STATE st =
                        value ? LB_API2_Declarations.FEATURE_STATE.ST_ON : LB_API2_Declarations.FEATURE_STATE.ST_OFF;
                    int rtn = LB_API2_Declarations.LB_SetTTLTriggerInEnabled(_sensDesc[0].DeviceAddress, st);
                    if (rtn > 0)
                    {
                        ShowMessage?.Invoke("SetTriggerInEnable Ok");
                        _triggerInEnable = value;
                    }
                    else
                    {
                        ShowMessage?.Invoke("SetTriggerInEnable *FAILED*");
                    }
                }
                catch (Exception ex)
                {
                    throw new ApplicationException("Error setting TriggerInEnable", ex);
                }
            }
        }

        int _triggerInTimeout;
        public int TriggerInTimeout
        {
            get { return _triggerInTimeout; }
            set
            {
                try
                {
                    int rtn = LB_API2_Declarations.LB_SetTTLTriggerInTimeOut(_sensDesc[0].DeviceAddress, value);
                    if (rtn > 0)
                    {
                        ShowMessage?.Invoke("SetTriggerInTimeout Ok");
                        _triggerInTimeout = value;
                    }
                    else
                    {
                        ShowMessage?.Invoke("SetTriggerInTimeout *FAILED*");
                    }
                }
                catch (Exception ex)
                {
                    throw new ApplicationException("Error setting TriggerInTimeout", ex);
                }
            }
        }

        bool _triggerOutEnable;
        public bool TriggerOutEnable
        {
            get { return _triggerOutEnable; }
            set
            {
                try
                {
                    LB_API2_Declarations.FEATURE_STATE st =
                        value ? LB_API2_Declarations.FEATURE_STATE.ST_ON : LB_API2_Declarations.FEATURE_STATE.ST_OFF;
                    int rtn = LB_API2_Declarations.LB_SetTTLTriggerOutEnabled(_sensDesc[0].DeviceAddress, st);
                    if (rtn > 0)
                    {
                        ShowMessage?.Invoke("SetTriggerOutEnable Ok");
                        _triggerOutEnable = value;
                    }
                    else
                    {
                        ShowMessage?.Invoke("SetTriggerOutEnable *FAILED*");
                    }
                }
                catch (Exception ex)
                {
                    throw new ApplicationException("Error setting TriggerOutEnable", ex);
                }
            }
        }

        bool _dutyCycleEnable;
        public bool DutyCycleEnable
        {
            get { return _dutyCycleEnable; }
            set
            {
                try
                {
                    LB_API2_Declarations.FEATURE_STATE st =
                        value ? LB_API2_Declarations.FEATURE_STATE.ST_ON : LB_API2_Declarations.FEATURE_STATE.ST_OFF;
                    int rtn = LB_API2_Declarations.LB_SetDutyCycleEnabled(_sensDesc[0].DeviceAddress, st);
                    if (rtn > 0)
                    {
                        ShowMessage?.Invoke("SetDutyCycleEnable Ok");
                        _dutyCycleEnable = value;
                    }
                    else
                    {
                        ShowMessage?.Invoke("SetDutyCycleEnable *FAILED*");
                    }
                }
                catch (Exception ex)
                {
                    throw new ApplicationException("Error setting DutyCycleEnable", ex);
                }
            }
        }

        int _dutyCyclePercent;
        public int DutyCyclePercent
        {
            get { return _dutyCyclePercent; }
            set
            {
                try
                {
                    int rtn = LB_API2_Declarations.LB_SetDutyCyclePerCent(_sensDesc[0].DeviceAddress, value);
                    if (rtn > 0)
                    {
                        ShowMessage?.Invoke("SetDutyCyclePercent Ok");
                        _dutyCyclePercent = value;
                    }
                    else
                    {
                        ShowMessage?.Invoke("SetDutyCyclePercent *FAILED*");
                    }
                }
                catch (Exception ex)
                {
                    throw new ApplicationException("Error setting DutyCyclePercent", ex);
                }
            }
        }


        bool _offsetEnable;
        public bool OffsetEnable
        {
            get { return _offsetEnable; }
            set
            {
                try
                {
                    LB_API2_Declarations.FEATURE_STATE st =
                        value ? LB_API2_Declarations.FEATURE_STATE.ST_ON : LB_API2_Declarations.FEATURE_STATE.ST_OFF;
                    int rtn = LB_API2_Declarations.LB_SetOffsetEnabled(_sensDesc[0].DeviceAddress, st);
                    if (rtn > 0)
                    {
                        ShowMessage?.Invoke("SetOffsetEnable Ok");
                        _offsetEnable = value;
                    }
                    else
                    {
                        ShowMessage?.Invoke("SetOffsetEnable *FAILED*");
                    }
                }
                catch (Exception ex)
                {
                    throw new ApplicationException("Error setting OffsetEnable", ex);
                }
            }
        }

        double _offset;
        public double Offset
        {
            get
            {
                try
                {
                    int rtn = LB_API2_Declarations.LB_GetOffset(_sensDesc[0].DeviceAddress, ref _offset);
                    if (rtn > 0)
                    {
                        ShowMessage?.Invoke(string.Format("GetOffset:{0:f1}", _offset));
                    }
                    else
                    {
                        ShowMessage?.Invoke("GetOffset *FAILED*");
                    }
                }
                catch (Exception ex)
                {
                    throw new ApplicationException("Error setting Offset", ex);
                }
                return _offset;
            }
            set
            {
                try
                {
                    int rtn = LB_API2_Declarations.LB_SetOffset(_sensDesc[0].DeviceAddress, value);
                    if (rtn > 0)
                    {
                        ShowMessage?.Invoke("SetOffset Ok");
                        _offset = value;
                    }
                    else
                    {
                        ShowMessage?.Invoke("SetOffset *FAILED*");
                    }
                }
                catch (Exception ex)
                {
                    throw new ApplicationException("Error setting Offset", ex);
                }
            }
        }

        bool _externalTrigger;
        public bool ExternalTrigger
        {
            get
            {
                return _externalTrigger;
                //if()
                //LB_API2_Declarations.FEATURE_STATE st = LB_API2_Declarations.FEATURE_STATE.ST_OFF;
                //int rtn = LB_API2_Declarations.LB_GetTTLTriggerInEnabled(_sensDesc[0].DeviceAddress, ref st);
                //if (rtn > 0)
                //{
                //    bool tmp = st == LB_API2_Declarations.FEATURE_STATE.ST_OFF ? false : true;
                //    ShowMessage?.Invoke(string.Format("ExternalTriggerEnabled:{0}", tmp));
                //    return tmp;
                //}
                //else
                //{
                //    ShowMessage?.Invoke("GetExternalTriggerEnabled *FAILED*");
                //    return false;
                //}
            }
            set
            {
                try
                {
                    LB_API2_Declarations.FEATURE_STATE st =
                        value ? LB_API2_Declarations.FEATURE_STATE.ST_ON : LB_API2_Declarations.FEATURE_STATE.ST_OFF;
                    int rtn = LB_API2_Declarations.LB_SetTTLTriggerInEnabled(_sensDesc[0].DeviceAddress, st);
                    if (rtn > 0)
                    {
                        ShowMessage?.Invoke(string.Format("SetExternalTrigger {0} Ok", value ? "ON" : "OFF"));
                        _externalTrigger = value;
                    }
                    else
                    {
                        ShowMessage?.Invoke("SetExternalTrigger *FAILED*");
                    }
                }
                catch (Exception ex)
                {
                    throw new ApplicationException("Error setting External Trigger", ex);
                }
            }
        }

        void AddSensor(string sensor)
        {
            _sensorList.Add(sensor);
            ShowMessage?.Invoke(sensor);
        }

        public void Startup(string resourceEnumerator, string device)
        {
            throw new NotImplementedException();
            //_rm = ResourceManager.GetLocalManager();
            //if (_rm == null)
            //    throw new ApplicationException("NI Resource Manager not found. Is NI VISA installed?");
            //string[] resources = _rm.FindResources("GPIB0::?*INSTR");
            //if (resources == null || resources.Length == 0)
            //    throw new ApplicationException("NI VISA error:No GPIB devices found");

            //_gpibName = resources[0];
            //_gpib = null;
            //try
            //{
            //    //_gpib = (GpibSession)_rm.Open(_gpibName);
            //}
            //catch (Exception ex)
            //{
            //    //throw new ApplicationException("NI VISA error opening GPIB device", ex);
            //}
        }

        public void Startup()
        {
            try
            {
                _sensorCount = LB_API2_Declarations.LB_SensorCnt();
                _sensorList = new List<string>();
                if (_sensorCount > 0)
                {
                    // create array of sensor descriptions
                    _sensDesc = new LB_API2_Declarations.SDByte[_sensorCount];
                    // get the descriptoins
                    int rslt = LB_API2_Declarations.LB_SensorList(ref _sensDesc[0], _sensorCount);
                    // if we got descriptions then put them in the list box for all to see
                    if (rslt >= 1)
                    {
                        for (int i = 0; i < _sensorCount; i++)
                        {
                            string strSensDesc = string.Concat(string.Format("{0,3:d}    {1,3:d}    ",
                                            _sensDesc[i].DeviceIndex, _sensDesc[i].DeviceAddress), _sensDesc[i].SN());
                            AddSensor(strSensDesc);
                        }

                        ShowMessage?.Invoke(string.Format("Initializing {0} LadyBug sensor{1}...", _sensorCount, _sensorCount > 1?"s":""));
                        rslt = LB_API2_Declarations.LB_InitializeSensor_Idx(_sensDesc[0].DeviceIndex);
                        if (rslt >= 1)
                            ShowMessage?.Invoke("LadyBug sensor initialize successful");
                        else
                            ShowMessage?.Invoke("LadyBug sensor initialize *FAILED*");
                    }
                    else
                    {
                        _sensorList.Add(string.Concat("Error - ", rslt.ToString()));
                    }
                }
                else
                {
                    ShowMessage?.Invoke("No LadyBug sensor detected on USB");
                }
            }
            catch { throw; }
        }

        public void Shutdown()
        {
            //if(_gpib != null)
            //{
            //    _gpib.Dispose();
            //    _gpib = null;
            //    _rm = null;
            //}
        }

        public void Reset()
        {
            throw new NotImplementedException();
        }

        public void Write(string scpi)
        {
            //if (_gpib == null)
            //    throw new ApplicationException("GPIB device is null, can't write anything");
            //_gpib.Write(scpi);
        }

        public void Write(byte[] data)
        {
            //if (_gpib == null)
            //    throw new ApplicationException("GPIB device is null, can't write anything");
            //_gpib.Write(data);
        }

        public string Read()
        {
            //if (_gpib == null)
            //    throw new ApplicationException("GPIB device is null, can't read");
            //return _gpib.Query("READ?");
            return "";
        }

        public string Read(string readCommand)
        {
            //if (_gpib == null)
            //    throw new ApplicationException("GPIB device is null, can't read");
            //return _gpib.Query(readCommand);
            return "";
        }

        public double Result(string readCommand)
        {
            //string data = Read(readCommand);
            //double result;
            //bool ok = Double.TryParse(data, out result);
            //return ok ? result : Double.NaN;
            return 0.0;
        }

        public void SetFrequency(double mHz)
        {
            try
            {
                if (_sensorCount > 0)
                {
                    double hertz = mHz * 1.0e6;
                    if (LB_API2_Declarations.LB_SetFrequency(_sensDesc[0].DeviceAddress, hertz) > 0)
                    {
                        ShowMessage?.Invoke(string.Format("SetFrequency {0:f1}mHz successful", mHz));
                    }
                    else
                    {
                        ShowMessage?.Invoke(string.Format("SetFrequency {0:f}mHz *FAILED*", mHz));
                    }
                }
                else
                {
                    ShowMessage?.Invoke("No LadyBug sensor detected on USB");
                }
            }
            catch (Exception ex)
            {
                throw new ApplicationException("Error:LadyBug power sensor SetFrequency failed", ex);
            }
        }

        public void SetPowerUnits(int powerUnits)
        {
            try
            {
                if (_sensorCount > 0)
                {

                    LB_API2_Declarations.PWR_UNITS units = (LB_API2_Declarations.PWR_UNITS)powerUnits;
                    if (LB_API2_Declarations.LB_SetMeasurementPowerUnits(_sensDesc[0].DeviceAddress, units) > 0)
                    {
                        ShowMessage?.Invoke(string.Format("SetPowerUnits {0} successful", powerUnits));
                    }
                    else
                    {
                        ShowMessage?.Invoke(string.Format("SetPowerUnits {0} *FAILED*", powerUnits));
                    }
                }
                else
                {
                    ShowMessage?.Invoke("No LadyBug sensor detected on USB");
                }
            }
            catch (Exception ex)
            {
                throw new ApplicationException("Error:LadyBug power sensor SetPowerUnits failed", ex);
            }
        }

        public void SetAverages(int avgs)
        {
            try
            {
                if (_sensorCount > 0)
                {
                    if (LB_API2_Declarations.LB_SetAverages(_sensDesc[0].DeviceAddress, avgs) > 0)
                    {
                        ShowMessage?.Invoke(string.Format("SetAverages {0} successful", avgs));
                    }
                    else
                    {
                        ShowMessage?.Invoke(string.Format("SetAverages {0} *FAILED*", avgs));
                    }
                }
                else
                {
                    ShowMessage?.Invoke("No LadyBug sensor detected on USB");
                }
            }
            catch (Exception ex)
            {
                throw new ApplicationException("Error:LadyBug power sensor SetAverages failed", ex);
            }
        }

        public double ReadCw(bool continuous)
        {
            //LB_API2_Declarations.PASS_FAIL_RESULT pf = LB_API2_Declarations.PASS_FAIL_RESULT.NO_DETERMINATION;
            double cw = 0.0;
            int rslt = LB_API2_Declarations.LB_MeasureCW(_sensDesc[0].DeviceAddress, ref cw);
            string result = "(none)";
            if (rslt > 0)            // if rslt is positive everything is ok
            {
                LB_API2_Declarations.PWR_UNITS CURR_UNITS = LB_API2_Declarations.PWR_UNITS.DBM;
                switch (CURR_UNITS)
                {
                    case LB_API2_Declarations.PWR_UNITS.DBKW:
                        result = string.Format("{0:F} dBkW", cw);
                        break;
                    case LB_API2_Declarations.PWR_UNITS.DBM:
                        result = string.Format("{0:F} dBm", cw);
                        break;
                    case LB_API2_Declarations.PWR_UNITS.DBREL:
                        result = string.Format("{0:F} dB (rel)", cw);
                        break;
                    case LB_API2_Declarations.PWR_UNITS.DBUV:
                        result = string.Format("{0:F} dBuV", cw);
                        break;
                    case LB_API2_Declarations.PWR_UNITS.DBW:
                        result = string.Format("{0:F} dBW", cw);
                        break;
                    case LB_API2_Declarations.PWR_UNITS.V:
                        result = string.Format("{0:E} V", cw);
                        break;
                    case LB_API2_Declarations.PWR_UNITS.W:
                        result = string.Format("{0:E} W", cw);
                        break;
                }
            }
            else result = "Read LadyBug CW *FAILED*";
            //ShowMessage?.Invoke(result);
            return cw;
        }

        public double ReadPulsed(bool continuous)
        {
            int rslt = 0;
            double pls = 0.0;
            double pk = 0.0;
            double cw = 0.0;
            double dc = 0.0;
            string result = "(none)";
            rslt = LB_API2_Declarations.LB_MeasurePulse(_sensDesc[0].DeviceAddress, ref pls, ref pk, ref cw, ref dc);
            if (rslt > 0)            // if rslt is positive everything is ok
            {
                LB_API2_Declarations.PWR_UNITS CURR_UNITS = LB_API2_Declarations.PWR_UNITS.DBM;
                switch (CURR_UNITS)
                {
                    case LB_API2_Declarations.PWR_UNITS.DBKW:
                        result = string.Format("Pulse={0:F} dBkW,  Peak={1:F} dBkW, CW={2:F} dBkW, DC={3:F}%,",
                                                                pls, pk, cw, dc * 100.0);
                        break;
                    case LB_API2_Declarations.PWR_UNITS.DBM:
                        result = string.Format("Pulse={0:F} dBm,  Peak={1:F} dBm, CW={2:F} dBm, DC={3:F}%,",
                                                                pls, pk, cw, dc * 100.0);
                        break;
                    case LB_API2_Declarations.PWR_UNITS.DBREL:
                        result = string.Format("Pulse={0:F} dB,  Peak={1:F} dB, CW={2:F} dB, DC={3:F}%,",
                                                                pls, pk, cw, dc * 100.0);
                        break;
                    case LB_API2_Declarations.PWR_UNITS.DBUV:
                        result = string.Format("Pulse={0:F} dBuV,  Peak={1:F} dBuV, CW={2:F} dBuV, DC={3:F}%,",
                                                                pls, pk, cw, dc * 100.0);
                        break;
                    case LB_API2_Declarations.PWR_UNITS.DBW:
                        result = string.Format("Pulse={0:F} dBW,  Peak={1:F} dBW, CW={2:F} dBW, DC={3:F}%,",
                                                                pls, pk, cw, dc * 100.0);
                        break;
                    case LB_API2_Declarations.PWR_UNITS.V:
                        result = string.Format("Pulse={0:E} V,  Peak={1:E} V, CW={2:E} V, DC={3:F}%,",
                                                                pls, pk, cw, dc * 100.0);
                        break;
                    case LB_API2_Declarations.PWR_UNITS.W:
                        result = string.Format("Pulse={0:E} W,  Peak={1:E} W, CW={2:E} WBm, DC={3:F}%,",
                                                                pls, pk, cw, dc * 100.0);
                        break;
                }
            }
            else result = "Read LadyBug PULSED *FAILED*";
            //ShowMessage?.Invoke(result);
            return pls;
        }
    }
}
