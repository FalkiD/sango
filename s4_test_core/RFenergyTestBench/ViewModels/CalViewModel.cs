using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Reactive.Linq;
using ReactiveUI;
using RFenergyUI.Views;
using Newtonsoft.Json;
using M2TestModule;
using Interfaces;

namespace RFenergyUI.ViewModels
{
    public class PowerCalData
    {
        public int IQDacMag { get; set; }
        public double PowerDB { get; set; }
        public double ExternaldBm { get; set; }
        public double Coupler { get; set; }
        public double Temperature { get; set; } // Average
        public double Volts { get; set; }       // Average
        public double Amps { get; set; }        // Max
    }

    public class CalViewModel : ReactiveObject
    {
        CalView _calview;

        const string STR_START_PWRCAL = "Run PwrCal";
        const string STR_STOP_PWRCAL = "Stop PwrCal";
        const string STR_START_TMPCOEFF = "Temp Measure";
        const string STR_STOP_TMPCOEFF = "Stop Tmp Meas";

        const int MAX_METER_BREAKPOINT = 2048;
        const int MIN_METER_BREAKPOINT = 0;

        public CalViewModel(CalView view)
        {
            _calview = view;
            MainViewModel.CalPanel = this;

            CmdInit = ReactiveCommand.CreateAsyncObservable(x => CmdInitRun());
            CmdInit.Subscribe(result => MainViewModel.MsgAppendLine(result));

            CmdReadCw = ReactiveCommand.CreateAsyncObservable(x => CmdReadCwRun());
            CmdReadCw.Subscribe(result => MainViewModel.MsgAppendLine(result));

            CmdReadPulsed = ReactiveCommand.CreateAsyncObservable(x => CmdRdPulsedRun());
            CmdReadPulsed.Subscribe(result => MainViewModel.MsgAppendLine(result));

            CmdEnableOffset = ReactiveCommand.CreateAsyncObservable(x => CmdEnableOffsetRun());
            CmdEnableOffset.Subscribe(result => MainViewModel.MsgAppendLine(result));

            CmdOffsets = ReactiveCommand.CreateAsyncObservable(x => CmdOffsetsRun(x));
            CmdOffsets.Subscribe(result => MainViewModel.MsgAppendLine(result));

            CmdFreq = ReactiveCommand.CreateAsyncObservable(x => CmdFreqRun(x));
            CmdFreq.Subscribe(result => MainViewModel.MsgAppendLine(result));

            CmdTriggerDelay = ReactiveCommand.CreateAsyncObservable(x => CmdTrigDlyRun(x));
            CmdTriggerDelay.Subscribe(result => MainViewModel.MsgAppendLine(result));

            CmdTriggerWidth = ReactiveCommand.CreateAsyncObservable(x => CmdTrigWidthRun(x));
            CmdTriggerWidth.Subscribe(result => MainViewModel.MsgAppendLine(result));

            // Power calibration routines
            CmdPwrCal = ReactiveCommand.CreateAsyncObservable(x => CmdPwrCalRun());
            CmdPwrCal.Subscribe(result => MainViewModel.MsgAppendLine(result));
            PwrCalRunning = false;
            PwrCalBtnTxt = STR_START_PWRCAL;
            CmdPwrCalArrow = ReactiveCommand.CreateAsyncObservable(x => CmdPwrCalArrowRun(x));
            CmdPwrCalArrow.Subscribe(result => MainViewModel.MsgAppendLine(result));

            CmdAverages = ReactiveCommand.CreateAsyncObservable(x => CmdAvgRun(x));
            CmdAverages.Subscribe(result => MainViewModel.MsgAppendLine(result));

            CmdCouplerOffsets = ReactiveCommand.CreateAsyncObservable(x => CmdCouplerOffsetsRun());
            CmdCouplerOffsets.Subscribe(result => MainViewModel.MsgAppendLine(result));

            CmdTempCoefficient = ReactiveCommand.CreateAsyncObservable(x => CmdTempCoefficientRun());
            CmdTempCoefficient.Subscribe(result => MainViewModel.MsgAppendLine(result));

            // Meter cal
            CmdMtrCal = ReactiveCommand.CreateAsyncObservable(x => CmdMtrCalRun());
            CmdMtrCal.Subscribe(result => MainViewModel.MsgAppendLine(result));
            //CmdMtrBreakpointArrow = ReactiveCommand.CreateAsyncObservable(x => CmdMtrBreakpointArrowRun(x));
            //CmdMtrBreakpointArrow.Subscribe(result => MainViewModel.MsgAppendLine(result));

            CouplerFwdOffset = CouplerReflOffset = 0;

            // Set some defaults, still must press Enter to send to LaadyBug
            Offsets = 54.34;
            Frequency = 2450;
            Averages = 200;
            PowerStepSize = 0.5;
            PowerStart = 2.76;          // dB for ~0xb0 start
            TargetStart = 40.0;
            PowerStop = 26.0;
            Compression = 2.0;
            MeterBreakpoint = 500;
            LowSlope = 6.4;
            LowIntercept = 6.0;
            HighSlope = 7.6;
            HighIntercept = -2.0;

            ResultsFile = "PowerCalResults.json";
            SkipCollectData = false;
            TempMeasPeriod = 500;
            TempMeasTime = 30000;
            TempCoeffBtnTxt = STR_START_TMPCOEFF;
        }

        /// <summary>
        /// DAC = 10^(dB/20)
        /// </summary>
        public ReactiveCommand<string> CmdPwrCal { get; protected set; }
        IObservable<string> CmdPwrCalRun()
        {
            string result = "";
            try
            {
                if (MainViewModel.ICmd != null)
                {
                    if (PwrCalRunning)
                    {
                        PwrCalBtnTxt = STR_START_PWRCAL;
                        PwrCalRunning = false;
                        result = " Power cal stopped";
                    }
                    else
                    {
                        PwrCalBtnTxt = STR_STOP_PWRCAL;
                        PwrCalRunning = true;
                        BackgroundWorker worker = new BackgroundWorker();
                        worker.WorkerReportsProgress = true;
                        worker.DoWork += pwrcal_DoWork;
                        worker.ProgressChanged += pwrcal_ProgressChanged;
                        worker.RunWorkerCompleted += pwrcal_RunWorkerCompleted;
                        worker.RunWorkerAsync(1000000);
                        result = string.Format(" begin power cal, start:{0:f1}, end:{1:f1}, stepsize:{2:f1}", PowerStart, PowerStop, PowerStepSize);
                    }
                }
                else result = "ICmd interface is null, can't execute anything";
            }
            catch (Exception ex)
            {
                result = string.Format("Power cal exception:{0}", ex.Message);
            }
            return Observable.Return(result);
        }
        /// <summary>
        /// 14-May re-do using dB instead of DAC count.
        /// 0dB = 0x80
        /// ADC = 10^(dB/20) * 0x80
        /// 
        /// Note: Unit 1 40dBm was around 0xb0,  this is
        /// 2.77 dB, use this for power start
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        void pwrcal_DoWork(object sender, DoWorkEventArgs e)
        {
            BackgroundWorker wrk = (sender as BackgroundWorker);
            string result = "";
            if (MsPerStep == 0)
                MsPerStep = 250;

            StreamWriter fout = null;
            try
            {
                fout = OpenCalFile("RfePowerCal.txt");
                string hdr = string.Format(" {0} RF Energy Source Calibration", MainViewModel.SelectedSystemName);
                WriteCalDataHeader(fout, hdr);
            }
            catch (Exception fileEx)
            {
                wrk.ReportProgress(0, 
                    string.Format("Exception opening cal data file:{0}", fileEx.Message));
            }

            if(SkipCollectData)
                RestoreCalResults(ResultsFile, wrk);

            SetDutyCycleCompensation(false);

            try
            {
                bool inCompression = false;
                double dBmTarget = TargetStart;
                double tolerance = 0.05;
                int MAX_ITERATIONS = 20;
                int MIN_ADJUST = 1;
                double MAX_DBMOUT = 62.0;
                double MAX_POWER = -1.0;    // keep track of max
                const double COMPRESSION_CHECK = 50.0;  // don't check compression until above this power

                double nextValue = PowerStart;
                if(SkipCollectData == false)
                    CalResults = new ObservableCollection<PowerCalData>();
                double lastValue = Double.NaN;
                double gain = Double.NaN;
                double maxGain = 0.0;
                while (PwrCalRunning && nextValue < PowerStop 
                        && !inCompression && !SkipCollectData)
                {
                    int status = SetCalPower(nextValue);
                    if (status != 0)
                    {
                        result = string.Format(" Set power {0:f1} failed, status:{1}, exit cal", nextValue, status);
                        PwrCalRunning = false;
                        wrk.ReportProgress(0, result);
                        break;
                    }

                    double externalPwr = ReadExternal(dBmTarget);
                    if (externalPwr > MAX_POWER)
                        MAX_POWER = externalPwr;
                    if (externalPwr > MAX_DBMOUT)
                        break;

                    // half steps for iterations
                    double stepsize = PowerStepSize;
                    int iterations = 0;
                    bool converged = false;
                    bool high = true;   // enter binary search from high side
                    MonitorPa[] results = null;
                    if (externalPwr > (dBmTarget - PowerStepSize) ||
                        Math.Abs(externalPwr - dBmTarget) <= tolerance)
                    {
                        stepsize = PowerStepSize / 2.0;
                        do
                        {
                            PowerCalData caldata = null;

                            if ((Math.Abs(externalPwr - dBmTarget) <= tolerance) ||
                                (externalPwr > COMPRESSION_CHECK &&
                                 CheckCompression(maxGain, externalPwr, nextValue)))
                            {
                                // Update Pa status
                                System.Threading.Thread.Sleep(250);
                                if ((status = MainViewModel.ICmd.PaStatus(M2Cmd.PWR_ADC, ref results)) != 0)
                                {
                                    result = string.Format(" PaStatus read failed, status:{0}, exit cal", status);
                                    PwrCalRunning = false;
                                    wrk.ReportProgress(0, result);
                                    break;
                                }
                                caldata = new PowerCalData
                                {
                                    IQDacMag = SynDacValue(nextValue),  // for reference
                                    PowerDB = nextValue,
                                    Coupler = results[0].Forward,
                                    ExternaldBm = externalPwr,       // or target?
                                    Temperature = Temperature(results),
                                    Volts = Voltage(results),
                                    Amps = MaxCurrent(results)
                                };
                                CalResults.Add(caldata);
                                if (Math.Abs(externalPwr - dBmTarget) <= tolerance)
                                {
                                    if (!Double.IsNaN(lastValue))
                                    {
                                        stepsize = nextValue - lastValue;
                                        gain = externalPwr - nextValue;
                                        if (gain > maxGain)
                                            maxGain = gain;
                                    }
                                    lastValue = nextValue;
                                    result = string.Format(" Cal Entry, dB:{0,6:f3}, ExtdBm:{1,5:f2}, CouplerFwd:{2,4:f0}, Temp:{3,2:f0}, Volts:{4,5:f2}, Amps:{5,5:f2}, Stepsize:{6:f2}, Gain:{7,5:f2}",
                                                                nextValue,
                                                                externalPwr,
                                                                caldata.Coupler,
                                                                caldata.Temperature,
                                                                caldata.Volts,
                                                                caldata.Amps,
                                                                stepsize, gain);
                                    wrk.ReportProgress(0, result);
                                    WriteCalData(fout, result, caldata.IQDacMag);
                                    dBmTarget += PowerStepSize;
                                    converged = true;
                                    // Check compression too
                                    if (externalPwr > COMPRESSION_CHECK &&
                                        CheckCompression(maxGain, externalPwr, nextValue))
                                    {
                                        wrk.ReportProgress(0, "In compression, done.");
                                        inCompression = true;
                                    }
                                    break;  // Next target
                                }
                                else
                                //if (externalPwr > COMPRESSION_CHECK &&
                                //    CheckCompression(maxGain, externalPwr, nextValue))
                                {
                                    gain = externalPwr - nextValue; // hasn't been updated yet during binary search
                                    result = string.Format(" Compression, dB:{0,6:f3}, ExtdBm:{1,5:f2}, CouplerFwd:{2,4:f0}, Temp:{3,2:f0}, Volts:{4,5:f2}, Amps:{5,5:f2}, Stepsize:{6:f2}, Gain:{7,5:f2}",
                                                                nextValue,
                                                                externalPwr,
                                                                caldata.Coupler,
                                                                caldata.Temperature,
                                                                caldata.Volts,
                                                                caldata.Amps,
                                                                stepsize, gain);
                                    wrk.ReportProgress(0, result);
                                    WriteCalData(fout, result, caldata.IQDacMag);
                                    inCompression = true;
                                    break;
                                }
                            }

                            double lastTry = nextValue;
                            if (externalPwr > dBmTarget)
                            {
                                nextValue -= stepsize;
                                if (nextValue == lastTry)
                                    nextValue -= MIN_ADJUST;
                                if (!high)
                                {
                                    stepsize /= 2.0;
                                    high = true;
                                }
                            }
                            else
                            {
                                nextValue = nextValue += stepsize;
                                if (nextValue == lastTry)
                                    nextValue += MIN_ADJUST;
                                if (high)
                                {
                                    stepsize /= 2.0;
                                    high = false;
                                }
                            }
                            status = SetCalPower(nextValue);
                            System.Threading.Thread.Sleep(250);
                            externalPwr = ReadExternal(dBmTarget);
                        } while (PwrCalRunning &&
                                    nextValue < PowerStop &&
                                    ++iterations < MAX_ITERATIONS);
                    }

                    if (nextValue >= PowerStop)
                    {
                        result += string.Format(", Stopped, input dB >= Max({0})", PowerStop);
                        wrk.ReportProgress(0, result);
                        WriteCalData(fout, result);
                    }
                    else if (!converged && !inCompression)
                    {
                        System.Threading.Thread.Sleep(250);
                        if ((status = MainViewModel.ICmd.PaStatus(M2Cmd.PWR_ADC, ref results)) != 0)
                        {
                            result = string.Format(" PaStatus read failed, status:{0}, exit cal", status);
                            PwrCalRunning = false;
                            wrk.ReportProgress(0, result);
                            break;
                        }
                        result = string.Format(" Searching, dB:{0,6:f3}, ExtdBm:{1:f2}, CouplerFwd:{2,4:f0}, Temp:{3,2:f0}, Volts:{4,5:f2}, Amps:{5,5:f2}, Stepsize:{6:f2}",
                                                nextValue,
                                                externalPwr,
                                                results[0].Forward,
                                                Temperature(results),
                                                Voltage(results),
                                                MaxCurrent(results),
                                                stepsize);
                        if (iterations >= MAX_ITERATIONS)
                            result += ", *ERROR*, exceeded max iterations";
                        wrk.ReportProgress(0, result);
                        WriteCalData(fout, result);
                    }
                    nextValue += stepsize;
                }
                ResetPower();
                if(inCompression || SkipCollectData)
                {
                    if(UpdatePowerTable)
                        UpdateCalData(fout, wrk);
                    if(PersistCalData)
                        PersistCalResults(fout, wrk);
                }
                if(CalResults.Count > 0)
                {
                    SaveCalResults(ResultsFile, wrk);
                }
            }
            catch (Exception ex)
            {
                string err = string.Format("Exception in cal worker thread:{0}", ex.Message);
                wrk.ReportProgress(0, err);
                WriteCalData(fout, err);
            }
            CloseCalData(fout);
            e.Result = 0;
            SetDutyCycleCompensation(true);
        }

        /// <summary>
        /// Initially tested with high-to low power table 16-May-2017
        /// Swapped for low-to-high power table, leaving room for data
        /// up to 65.0dBm
        /// </summary>
        /// <param name="wnd"></param>
        void UpdateCalData(StreamWriter fout, BackgroundWorker wnd)
        {
            string msg = "";
            try
            {
                const int BLOCKS = 8;   // FW power table is 51 entries long from 40.0
                                        // to 65.0 dBm in 0.5 dBm steps. Requires 8
                                        // blocks

                // Fill 8 blocks. Last block will be null-terminated after TOP_INDEX
                const int ENTRIES_PER_BLOCK = 7;
                const int BYTES_PER_VALUE = 4;
                const int TOP_INDEX = ((int)((65.0 - 40.0) / 0.5) + 1)*BYTES_PER_VALUE;
                byte[] cmd = new byte[31];
                cmd[0] = M2Cmd.CAL_PWR;
                byte record = 0;
                int frq_index = 0;
                if (Frequency < 2420.0)
                    frq_index = 0;
                else if (Frequency < 2440.0)
                    frq_index = 1;
                else if (Frequency < 2460.0)
                    frq_index = 2;
                else if (Frequency < 2480.0)
                    frq_index = 3;
                else frq_index = 4;
                string strData;
                string str = "";
                for (int k = 0; k < BLOCKS * ENTRIES_PER_BLOCK;)
                {
                    strData = "";
                    for (int j = k; j < (record+1)*ENTRIES_PER_BLOCK; ++j)
                    {
                        if(j < CalResults.Count)
                        {
                            // Table in FW is low to high values
                            ushort data = (ushort)(CalResults[j].PowerDB * 100.0);
                            str = string.Format("{0:d4}", data);
                        }
                        strData += str;
                    }
                    byte byte1 = record++;
                    byte1 = (byte)((byte1 & 0xf) | (frq_index << 4));
                    cmd[1] = byte1;
                    for(int i = 0; i < ENTRIES_PER_BLOCK * BYTES_PER_VALUE; ++i)
                    {
                        if (k+i >= TOP_INDEX-1)   // Terminate after 51st entry
                            cmd[i+2] = 0;
                        else
                            cmd[i+2] = (byte)strData[i];
                    }
                    byte[] rsp = null;
                    int status = MainViewModel.ICmd.RunCmd(cmd, ref rsp);
                    if(status != 0)
                    {
                        msg = string.Format(" Write CalResults failed, status:{0}", MainViewModel.IErr.ErrorDescription(status));
                        wnd.ReportProgress(0, msg);
                        fout.WriteLine(MainViewModel.Timestamp + msg);
                        return;
                    }
                    k += ENTRIES_PER_BLOCK;
                }
                msg = " Wrote CalResults to device.";
                wnd.ReportProgress(0, msg);
                fout.WriteLine(MainViewModel.Timestamp + msg);
            }
            catch (Exception ex)
            {
                msg = string.Format(" Exception writing CalResults to device:{0}", ex.Message);
                wnd.ReportProgress(0, msg);
                fout.WriteLine(MainViewModel.Timestamp + msg);
            }
        }

        void RestoreCalResults(string resultsFile, BackgroundWorker wnd)
        {
            string filename = "";
            try
            {
                filename = Environment.GetFolderPath(Environment.SpecialFolder.CommonDocuments) +
                    "\\" + resultsFile;
                if (File.Exists(filename) == false)
                    return;
                StreamReader fin = new StreamReader(filename);
                if (fin != null)
                {
                    string json = fin.ReadToEnd();
                    fin.Close();
                    CalResults = JsonConvert.DeserializeObject<ObservableCollection<PowerCalData>>(json);
                }
            }
            catch (Exception ex)
            {
                wnd.ReportProgress(0, string.Format("Exception reading CalResults from JSON file{0}:{1}", filename, ex.Message));
            }
        }

        void SaveCalResults(string resultsFile, BackgroundWorker wnd)
        {
            string filename = "";
            try
            {
                string output = JsonConvert.SerializeObject(CalResults);
                filename = Environment.GetFolderPath(Environment.SpecialFolder.CommonDocuments) +
                    "\\" + resultsFile;
                StreamWriter fout = new StreamWriter(filename, false);
                if (fout != null)
                {
                    fout.Write(output);
                    fout.Close();
                }
            }
            catch(Exception ex)
            {
                wnd.ReportProgress(0, string.Format("Exception writing CalResults to JSON file{0}:{1}", filename, ex.Message));
            }
        }

        /// <summary>
        /// Issue FW command that writes power cal table to
        /// the tag PC2 for 2450MHz. 
        /// PC0=2410, PC1=2430, PC3=2470, PC4=2490)
        /// </summary>
        /// <param name="wnd"></param>
        void PersistCalResults(StreamWriter fout, BackgroundWorker wnd)
        {
            string msg = "";
            byte[] cmd = new byte[2];
            try
            {
                cmd[0] = M2Cmd.CAL_SAVE_PWRCAL;
                switch((int)Frequency)
                {
                    case 2410:
                        cmd[1] = 0;
                        break;
                    case 2430:
                        cmd[1] = 1;
                        break;
                    default:
                    case 2450:
                        cmd[1] = 2;
                        break;
                    case 2470:
                        cmd[1] = 3;
                        break;
                    case 2490:
                        cmd[1] = 4;
                        break;
                }
                byte[] rsp = null;
                int status = MainViewModel.ICmd.RunCmd(cmd, ref rsp);
                if (status != 0)
                {
                    msg = string.Format(" Persist CalResults failed, frequency:{0:f1} MHz, tag:{1}, status:{2}", 
                                            Frequency, cmd[1], MainViewModel.IErr.ErrorDescription(status));
                    wnd.ReportProgress(0, msg);
                    fout.WriteLine(MainViewModel.Timestamp + msg);
                    return;
                }
                msg = string.Format(" Persisted CalResults {0:f1} MHz to 'PC{1}' tag in EEPROM.", Frequency, cmd[1]);
                wnd.ReportProgress(0, msg);
                fout.WriteLine(MainViewModel.Timestamp + msg);
            }
            catch (Exception ex)
            {
                msg = string.Format(" Exception persisting CalResults to EEPROM tag PC{0}:{1}", cmd[1], ex.Message);
                wnd.ReportProgress(0, msg);
                fout.WriteLine(MainViewModel.Timestamp + msg);
            }
        }

        int SynDacValue(double db)
        {
            return (int)((Math.Pow(10.0, db / 20.0) * (double)0x80) + 0.5);
        }

        void pwrcal_ProgressChanged(object sender, ProgressChangedEventArgs e)
        {
            if (e.UserState != null)
                MainViewModel.MsgAppendLine((string)e.UserState);
        }

        void pwrcal_RunWorkerCompleted(object sender, RunWorkerCompletedEventArgs e)
        {
            PwrCalRunning = false;
            PwrCalBtnTxt = STR_START_PWRCAL;
            MainViewModel.MsgAppendLine("Power cal done");
        }

        /// <summary>
        /// Use the arrow button to single-step power cal
        /// Not used yet...
        /// </summary>
        public ReactiveCommand<string> CmdPwrCalArrow { get; protected set; }
        IObservable<string> CmdPwrCalArrowRun(object arrow)
        {
            string result = "";
            try
            {
                //double delta = arrow.ToString().StartsWith("up") ? VOLTS_PER_LSB : -VOLTS_PER_LSB;
                //DacValue += delta;
                if (PwrCalRunning)
                {
                    PwrCalBtnTxt = STR_START_PWRCAL;
                    PwrCalRunning = false;
                    result = " Power cal stopped";
                }


                return Observable.Return("PwrCalArrow done"); // CmdDacRun(DacValue.ToString());
            }
            catch (Exception ex)
            {
                result = string.Format("PwrCalArrow exception:{0}", ex.Message);
            }
            return Observable.Return(result);
        }
        // End of power cal


        public ReactiveCommand<string> CmdInit { get; protected set; }
        IObservable<string> CmdInitRun()
        {
            string result = "";
            try
            {
                if (MainViewModel.IMeter != null)
                {
                    MainViewModel.IMeter.Startup();
                    CmdOffsetsRun(Offsets.ToString());
                    CmdFreqRun(Frequency.ToString());
                    CmdAvgRun(Averages.ToString());
                    ExternalTrigger = MainViewModel.TestPanel.DutyCycle == 100 ? false : true;
                }
                else result = "MainViewModel.IMeter interface is null, can't execute anything";
            }
            catch (Exception ex)
            {
                result = string.Format("Initialize LadyBug sensor exception:{0}", ex.Message);
            }
            return Observable.Return(result);
        }

        public ReactiveCommand<string> CmdReadCw { get; protected set; }
        IObservable<string> CmdReadCwRun()
        {
            string result = "";
            try
            {
                if (MainViewModel.IMeter != null)
                {
                    Power = ReadExternal(40.0);
                    result = string.Format("LadyBug ReadCw:{0:f2} dBm", Power);
                }
                else result = "MainViewModel.IMeter interface is null, can't execute anything";
            }
            catch (Exception ex)
            {
                result = ex.Message;
            }
            return Observable.Return(result);
        }

        public ReactiveCommand<string> CmdReadPulsed { get; protected set; }
        IObservable<string> CmdRdPulsedRun()
        {
            string result = "";
            try
            {
                if (MainViewModel.IMeter != null)
                {
                    Power = ReadExternal(40.0);
                    result = string.Format("LadyBug ReadPulsed:{0:f2} dBm", Power);
                }
                else result = "MainViewModel.IMeter interface is null, can't execute anything";
            }
            catch (Exception ex)
            {
                result = ex.Message;
            }
            return Observable.Return(result);
        }

        public ReactiveCommand<string> CmdEnableOffset { get; protected set; }
        IObservable<string> CmdEnableOffsetRun()
        {
            string result = "";
            try
            {
                if (MainViewModel.IMeter != null)
                {
                    MainViewModel.IMeter.OffsetEnable = true;
                    result = "LadyBug EnableOffsets true";
                }
                else result = "MainViewModel.IMeter interface is null, can't execute anything";
            }
            catch (Exception ex)
            {
                result = string.Format("EnableOffsets exception:{0}", ex.Message);
            }
            return Observable.Return(result);
        }

        public ReactiveCommand<string> CmdOffsets { get; protected set; }
        IObservable<string> CmdOffsetsRun(object text)
        {
            string result = "";
            try
            {
                if (MainViewModel.IMeter != null)
                {
                    double value;
                    if (Double.TryParse(text.ToString(), out value))
                    {
                        Offsets = value;
                        if (Offsets < 0.0 || Offsets > 65.0)
                            return Observable.Return(string.Format("Offset out of range({0}) must be between 0 and 65", Offsets));
                        MainViewModel.IMeter.Offset = Offsets;
                        result = string.Format("Offsest set to {0}", Offsets);
                        double check = MainViewModel.IMeter.Offset;
                        result += string.Format(", read:{0:f1}", check);

                        CmdEnableOffsetRun();
                    }
                    else
                        return Observable.Return(string.Format("Error, cannot convert '{0}' to a double", text.ToString()));
                }
                else result = "MainViewModel.IMeter interface is null, can't execute anything";
            }
            catch (Exception ex)
            {
                result = string.Format("Offsets exception:{0}", ex.Message);
            }
            return Observable.Return(result);
        }

        public ReactiveCommand<string> CmdFreq { get; protected set; }
        IObservable<string> CmdFreqRun(object text)
        {
            string result = "";
            try
            {
                if (MainViewModel.IMeter != null)
                {
                    double value;
                    if (Double.TryParse(text.ToString(), out value))
                    {
                        if (value < 2400.0 || value > 2500.0)
                            return Observable.Return(string.Format("Frequency out of range({0}) must be between 2400 and 2500", value));
                        Frequency = value;
                        MainViewModel.IMeter.SetFrequency(Frequency);
                        result = string.Format("LadyBug SetFrequency {0:f1} mHz", Frequency);
                    }
                    else
                        return Observable.Return(string.Format("Error, cannot convert '{0}' to a double", text.ToString()));
                }
                else result = "MainViewModel.IMeter interface is null, can't execute anything";
            }
            catch (Exception ex)
            {
                result = string.Format("Set LadyBug frequency exception:{0}", ex.Message);
            }
            return Observable.Return(result);
        }

        public ReactiveCommand<string> CmdTriggerDelay { get; protected set; }
        IObservable<string> CmdTrigDlyRun(object text)
        {
            string result = "";
            try
            {
                int value;
                if (int.TryParse(text.ToString(), out value))
                {
                    TriggerDelay = value;
                    MainViewModel.IMeter.TriggerInTimeout = TriggerDelay;
                    result = string.Format("TriggerInTimeout set to {0}", TriggerDelay);
                }
                else
                    return Observable.Return(string.Format("Error, cannot convert '{0}' to an int", text.ToString()));
            }
            catch (Exception ex)
            {
                result = string.Format("TriggerDelay exception:{0}", ex.Message);
            }
            return Observable.Return(result);
        }

        public ReactiveCommand<string> CmdTriggerWidth { get; protected set; }
        IObservable<string> CmdTrigWidthRun(object text)
        {
            string result = "";
            try
            {
                int value;
                if (int.TryParse(text.ToString(), out value))
                {
                    TriggerWidth = value;
                    MainViewModel.IMeter.TriggerInTimeout = TriggerWidth;
                    result = string.Format("TriggerInTimeout set to {0}", TriggerDelay);
                }
                else
                    return Observable.Return(string.Format("Error, cannot convert '{0}' to an int", text.ToString()));
            }
            catch (Exception ex)
            {
                result = string.Format("TriggerWidth exception:{0}", ex.Message);
            }
            return Observable.Return(result);
        }

        public ReactiveCommand<string> CmdAverages { get; protected set; }
        IObservable<string> CmdAvgRun(object text)
        {
            string result = "";
            try
            {
                int value;
                if (int.TryParse(text as string, out value))
                {
                    MainViewModel.IMeter.SetAverages(value);
                    return Observable.Return("CmdAverages done");
                }
                else return Observable.Return(string.Format("Can't convert {0} to integer", text.ToString()));
            }
            catch (Exception ex)
            {
                result = string.Format("CmdAverages exception:{0}", ex.Message);
            }
            return Observable.Return(result);
        }

        public ReactiveCommand<string> CmdMtrCal { get; protected set; }
        IObservable<string> CmdMtrCalRun()
        {
            string result = "";
            try
            {
                if (MeterBreakpoint < MIN_METER_BREAKPOINT &&
                    MeterBreakpoint > MAX_METER_BREAKPOINT)
                {
                    return Observable.Return(string.Format("MeterBreakpont out of range({0}) must be between {1} and {2}",
                                                                                    MeterBreakpoint, MIN_METER_BREAKPOINT, MAX_METER_BREAKPOINT));
                }
                if (MainViewModel.IDbg != null)
                {
                    byte[] cmd = new byte[M2Cmd.MTR_CAL_DATA + 1];
                    cmd[0] = M2Cmd.CAL_MTR;
                    cmd[1] = M2Cmd.MTR_UPDATE_INUSE;
                    if (WriteMtrTag)
                        cmd[1] |= (byte)M2Cmd.MTR_UPDATE_EEPROM;
                    cmd[2] = (byte)((short)MeterBreakpoint & 0xff);
                    cmd[3] = (byte)(((short)MeterBreakpoint >> 8) &0xff);
                    short tmp = (short)(LowSlope * 256.0);
                    cmd[4] = (byte)(tmp & 0xff);
                    cmd[5] = (byte)((tmp >> 8) & 0xff);
                    tmp = (short)(LowIntercept * 256.0);
                    cmd[6] = (byte)(tmp & 0xff);
                    cmd[7] = (byte)((tmp >> 8) & 0xff);

                    tmp = (short)(HighSlope * 256.0);
                    cmd[8] = (byte)(tmp & 0xff);
                    cmd[9] = (byte)((tmp >> 8) & 0xff);
                    tmp = (short)(HighIntercept * 256.0);
                    cmd[10] = (byte)(tmp & 0xff);
                    cmd[11] = (byte)((tmp >> 8) & 0xff);
                    byte[] data = null;
                    int status = MainViewModel.ICmd.RunCmd(cmd, ref data);
                    if (status == 0)
                        result = "CAL_MTR Ok\n";
                    else result = string.Format("CAL_MTR error:{0}", MainViewModel.IErr.ErrorDescription(status));
                }
                else result = "MainViewModel.IDbg interface is null, can't execute anything";
            }
            catch (Exception ex)
            {
                result = string.Format("CmdMtrCal exception:{0}", ex.Message);
            }
            return Observable.Return(result);
        }

        //public ReactiveCommand<string> CmdMtrBreakpointArrow { get; protected set; }
        //IObservable<string> CmdMtrBreakpointArrowRun(object arrow)
        //{
        //    string result = "";
        //    try
        //    {
        //        int delta = arrow.ToString().StartsWith("up") ? 1 : -1;
        //        if ((delta > 0 && MeterBreakpoint >= MAX_METER_BREAKPOINT-1) ||
        //            (delta < 0 && MeterBreakpoint <= MIN_METER_BREAKPOINT+1))
        //            delta = 0;
        //        MeterBreakpoint += delta;
        //        return Observable.Return(string.Format("MeterBreakpoint set to {0} (0x{0:03x})", MeterBreakpoint));
        //    }
        //    catch (Exception ex)
        //    {
        //        result = string.Format("MeterBreakpointArrow exception:{0}", ex.Message);
        //    }
        //    return Observable.Return(result);
        //}

        public ReactiveCommand<string> CmdCouplerOffsets { get; protected set; }
        IObservable<string> CmdCouplerOffsetsRun()
        {
            string result = "";
            try
            {
                int status = EnableChannels(false);
                if (status != 0)
                {
                    result = string.Format(" Disable channels failed, status:{0}", MainViewModel.IErr.ErrorDescription(status));
                    return Observable.Return(result);
                }
                System.Threading.Thread.Sleep(1000);

                double fwd, refl;
                fwd = refl = 0.0;
                status = ReadCoupler(M2Cmd.PWR_RAW, ref fwd, ref refl);
                if (status != 0)
                {
                    result = string.Format(" ReadCoupler failed, status:{0}", MainViewModel.IErr.ErrorDescription(status));
                    return Observable.Return(result);
                }
                // To display these 16-bit signed numbers check the sign here. They're passed
                // around as 16-bit unsigned #'s
                uint tmpl = (uint)fwd;
                unchecked
                {
                    if ((tmpl & 0x8000) == 0x8000)
                    {
                        tmpl |= 0xffff0000;
                    }
                }
                CouplerFwdOffset = (double)(int)tmpl;
                tmpl = (uint)refl;
                unchecked
                {
                    if ((tmpl & 0x8000) == 0x8000)
                    {
                        tmpl = tmpl | 0xffff0000;
                    }
                }
                CouplerReflOffset = (double)(int)tmpl;
                if(WriteFofRofTags)
                {
                    // Write these values to binary tags FOF & ROF
                    short tmp = (short)((int)CouplerFwdOffset & 0x3fff);
                    if((status = MainViewModel.IDbg.SetTag("FOF", BitConverter.GetBytes(tmp))) == 0)
                    {
                        tmp = (short)((int)CouplerReflOffset & 0x3fff);
                        status = MainViewModel.IDbg.SetTag("ROF", BitConverter.GetBytes(tmp));
                    }
                    if (status != 0)
                    {
                        result = string.Format(" Write FOF/ROF failed, status:{0}", MainViewModel.IErr.ErrorDescription(status));
                    }
                }

                status = EnableChannels(true);
                if (status != 0)
                {
                    result = string.Format(" Enable channels failed, status:{0}", MainViewModel.IErr.ErrorDescription(status));
                }
            }
            catch (Exception ex)
            {
                result = string.Format("CmdCouplerOffsets exception:{0}", ex.Message);
            }
            return Observable.Return(result);
        }

        /// <summary>
        /// Power should be low before starting so temperature is 25 or so
        /// </summary>
        public ReactiveCommand<string> CmdTempCoefficient { get; protected set; }
        IObservable<string> CmdTempCoefficientRun()
        {
            string result = "";
            try
            {
                if (TempCoeffRunning)
                {
                    TempCoeffBtnTxt = STR_START_TMPCOEFF;
                    TempCoeffRunning = false;
                    result = " Measure temp. coefficient stopped";
                }
                else
                {
                    TempCoeffBtnTxt = STR_STOP_TMPCOEFF;
                    TempCoeffRunning = true;
                    BackgroundWorker worker = new BackgroundWorker();
                    worker.WorkerReportsProgress = true;
                    worker.DoWork += tempCoeff_DoWork;
                    worker.ProgressChanged += pwrcal_ProgressChanged;
                    worker.RunWorkerCompleted += tempCoeff_RunWorkerCompleted;
                    worker.RunWorkerAsync(1000000);
                    result = " Measuring power over temperature";
                }
            }
            catch (Exception ex)
            {
                result = string.Format("CmdTempCoefficient exception:{0}", ex.Message);
            }
            return Observable.Return(result);
        }
        void tempCoeff_DoWork(object sender, DoWorkEventArgs e)
        {
            BackgroundWorker wrk = (sender as BackgroundWorker);
            StreamWriter ftmp = null;
            try
            {
                int status = MainViewModel.ICmd.SetPower(60.0);
                ftmp = OpenCalFile("TempCoefficient.csv");
                if (status == 0 && ftmp != null)
                {
                    int count = TempMeasTime / TempMeasPeriod + 1;
                    for (int k = 0; k < count && TempCoeffRunning; ++k)
                    {
                        int t = Temperature();
                        double dbm = ReadExternal(40.0);
                        string line = string.Format("{0},{1},{2},{3:f2}", MainViewModel.Timestamp, k, t, dbm);
                        ftmp.WriteLine(line);
                        wrk.ReportProgress(0, line);
                        if (TempCoeffRunning == false)
                            break;
                        System.Threading.Thread.Sleep(TempMeasPeriod);
                    }
                }
            }
            catch (Exception ex)
            {
                wrk.ReportProgress(0, string.Format("CmdTempCoefficient exception:{0}", ex.Message));
            }
            if (ftmp != null)
                ftmp.Close();
            MainViewModel.ICmd.SetPower(40.0);
            return;
        }
        void tempCoeff_RunWorkerCompleted(object sender, RunWorkerCompletedEventArgs e)
        {
            TempCoeffRunning = false;
            TempCoeffBtnTxt = STR_START_TMPCOEFF;
            MainViewModel.MsgAppendLine("Temperature measurement done");
        }

        // private funcs

        void NextCouplerReading(out double fwd, out double refl)
        {
            System.Threading.Thread.Sleep(1000);    // correct coupler reading until fw fix
            fwd = refl = 0;
            ReadCoupler(M2Cmd.PWR_ADC, ref fwd, ref refl);
        }

        /// <summary>
        /// Return average pallet temperature
        /// </summary>
        /// <returns></returns>
        int Temperature()
        {
            double temp = 0.0; ;
            int channel;
            byte[] cmd = new byte[1];
            cmd[0] = M2Cmd.RF_STATUS;
            byte[] data = null;
            int status = MainViewModel.ICmd.RunCmd(cmd, ref data);
            if (status == 0)
            {
                if (data != null)
                {
                    for (channel = 1; channel <= 4; ++channel)
                    {
                        int offset = 1 + 6 * (channel - 1);
                        int value = (data[offset + 1] << 8) | data[offset];
                        if ((value & 0x8000) != 0)
                            unchecked { value |= (int)0xffff0000; }
                        temp += (double)value / 256.0;
                    }
                    return (int)(temp / 4.0);
                }
            }
            return -1;
        }

        /// <summary>
        /// Return average pallet temperature from
        /// results array
        /// </summary>
        /// <returns></returns>
        int Temperature(MonitorPa[] results)
        {
            double temp = 0.0; ;
            for (int k = 0; k < results.Length; ++k)
            {
                temp += results[k].Temperature;
            }
            return (int)(temp / 4.0);
        }

        /// <summary>
        /// Return average pallet voltage from
        /// results array
        /// </summary>
        /// <returns></returns>
        double Voltage(MonitorPa[] results)
        {
            double volts = 0.0; ;
            for (int k = 0; k < results.Length; ++k)
            {
                volts += results[k].Voltage;
            }
            return (volts / 4.0);
        }

        /// <summary>
        /// Return maximum pallet current from
        /// results array
        /// </summary>
        /// <returns></returns>
        double MaxCurrent(MonitorPa[] results)
        {
            double maxAmps = Double.NegativeInfinity;
            for (int k = 0; k < results.Length; ++k)
            {
                if(results[k].Current > maxAmps)
                maxAmps = results[k].Current;
            }
            return maxAmps;
        }

        bool CheckCompression(double maxGain, double pOut, double pIn)
        {
            if (maxGain > 0)
            {
                double gain = pOut - pIn;
                if (gain < maxGain && (maxGain - gain) > Compression)
                    return true;
            }
            return false;
        }

        /// <summary>
        /// Argument only used when no hardware as dummy value
        /// </summary>
        /// <param name="dBmTarget"></param>
        /// <returns></returns>
        double ReadExternal(double dBmTarget)
        {
            try
            {
                System.Threading.Thread.Sleep(50);
                return dBmTarget - 0.01;

                if (MainViewModel.TestPanel.DutyCycle == 100)
                    return MainViewModel.IMeter.ReadCw(false);
                else
                    return MainViewModel.IMeter.ReadPulsed(false);
            }
            catch(Exception ex)
            {
                throw new ApplicationException("External meter exception, has it been initialized?", ex);
            }
        }

        StreamWriter OpenCalFile(string filename)
        {
            string name = Environment.GetFolderPath(Environment.SpecialFolder.CommonDocuments) + "\\" + filename;
            return new StreamWriter(name, true);
        }

        void WriteCalDataHeader(StreamWriter fout, string title)
        {
            if (fout != null)
            {
                fout.WriteLine(Environment.NewLine + MainViewModel.Timestamp + title);
                string data = string.Format(" Frequency:{0:f1} MHz, DutyCycle:{1}", 
                                            Frequency, MainViewModel.TestPanel.DutyCycle);
                fout.WriteLine(MainViewModel.Timestamp + data);
            }
        }

        void WriteCalData(StreamWriter fout, string line)
        {
            if (fout != null)
                fout.WriteLine(MainViewModel.Timestamp + line);
        }

        void WriteCalData(StreamWriter fout, string line, int synDac)
        {
            if (fout != null)
                fout.WriteLine(MainViewModel.Timestamp + line + string.Format(", SynDac:0x{0:x}", synDac));
        }

        void CloseCalData(StreamWriter fout)
        {
            if (fout != null)
                fout.Close();
        }

        int EnableChannels(bool enable)
        {
            byte[] cmd = new byte[2];
            cmd[0] = M2Cmd.RF_CTRL;
            cmd[1] = enable ? (byte)0xf : (byte)0;     // all 4 channels
            byte[] rsp = null;
            return MainViewModel.ICmd.RunCmd(cmd, ref rsp);
        }

        /// <summary>
        /// Raw coupler readings, no offsets removed
        /// </summary>
        /// <param name="forward"></param>
        /// <param name="reflected"></param>
        /// <returns></returns>
        int ReadCoupler(int type, ref double forward, ref double reflected)
        {
            forward = reflected = 0.0;
            int status = MainViewModel.ICmd.CouplerPower(type, ref forward, ref reflected);
            if (status == 0)
            {
                CouplerFwd = forward;
                CouplerRefl = reflected;
            }
            return status;
        }

        int SetDutyCycleCompensation(bool value)
        {
            return MainViewModel.ICmd.DutyCycleCompensation(value); ;
        }

        /// <summary>
        /// SynDac = 10^(db/20.0)
        /// assume 0dB is DAC 0x080
        /// </summary>
        /// <param name="value">gain in dB</param>
        /// <returns>0 on success, else error code</returns>
        public int SetCalPower(double value)
        {
            if (MainViewModel.ICmd.HwType == InstrumentInfo.InstrumentType.S4)
                System.Threading.Thread.Sleep(80);
            int status = MainViewModel.ICmd.SetCalPower(value);
            if (status == 0)
                MainViewModel.DebugPanel.PwrInDb = value;
            return status;
        }

        void ResetPower()
        {
            SetCalPower(PowerStart);
        }

        // props

        ObservableCollection<PowerCalData> _calResults;
        public ObservableCollection<PowerCalData> CalResults
        {
            get { return _calResults; }
            set { this.RaiseAndSetIfChanged(ref _calResults, value); }
        }

        double _couplerFwdOffset;
        public double CouplerFwdOffset
        {
            get { return _couplerFwdOffset; }
            set { this.RaiseAndSetIfChanged(ref _couplerFwdOffset, value); }
        }

        double _couplerReflOffset;
        public double CouplerReflOffset
        {
            get { return _couplerReflOffset; }
            set { this.RaiseAndSetIfChanged(ref _couplerReflOffset, value); }
        }

        bool _couplerWriteTags;
        public bool WriteFofRofTags
        {
            get { return _couplerWriteTags; }
            set { this.RaiseAndSetIfChanged(ref _couplerWriteTags, value); }
        }

        double _couplerRefl;
        public double CouplerRefl
        {
            get { return _couplerRefl - _couplerReflOffset; }
            set { this.RaiseAndSetIfChanged(ref _couplerRefl, value); }
        }
        double _couplerFwd;
        public double CouplerFwd
        {
            get { return _couplerFwd - _couplerReflOffset; }
            set { this.RaiseAndSetIfChanged(ref _couplerFwd, value); }
        }


        double _powerStart;
        public double PowerStart
        {
            get { return _powerStart; }
            set { this.RaiseAndSetIfChanged(ref _powerStart, value); }
        }
        double _targetStart;
        public double TargetStart
        {
            get { return _targetStart; }
            set { this.RaiseAndSetIfChanged(ref _targetStart, value); }
        }
        double _powerStop;
        public double PowerStop
        {
            get { return _powerStop; }
            set { this.RaiseAndSetIfChanged(ref _powerStop, value); }
        }
        double _powerStepSize;
        public double PowerStepSize
        {
            get { return _powerStepSize; }
            set { this.RaiseAndSetIfChanged(ref _powerStepSize, value); }
        }
        double _compression;
        public double Compression
        {
            get { return _compression; }
            set { this.RaiseAndSetIfChanged(ref _compression, value); }
        }

        bool _externalTrigger;
        public bool ExternalTrigger
        {
            get
            {
                if (MainViewModel.IMeter != null)
                {
                    _externalTrigger = MainViewModel.IMeter.ExternalTrigger;
                }
                return _externalTrigger;
            }
            set
            {
                try
                {
                    if (MainViewModel.IMeter != null)
                    {
                        MainViewModel.IMeter.ExternalTrigger = value;
                        MainViewModel.MsgAppendLine(string.Format("ExternalTrigger set{0}", value ? "ON" : "OFF"));
                        this.RaiseAndSetIfChanged(ref _externalTrigger, value);
                    }
                    else
                        MainViewModel.MsgAppendLine("IMeter is null, can't set ExternalTrigger");
                }
                catch (Exception ex)
                {
                    MainViewModel.MsgAppendLine(string.Format("TriggerWidth exception:{0}", ex.Message));
                }
            }
        }

        int _meterBreakpoint;
        public int MeterBreakpoint
        {
            get { return _meterBreakpoint; }
            set { this.RaiseAndSetIfChanged(ref _meterBreakpoint, value); }
        }

        int _meterAdc;
        public int MeterAdc
        {
            get { return _meterAdc; }
            set { this.RaiseAndSetIfChanged(ref _meterAdc, value); }
        }

        double _meterDbm;
        public double MeterDbm
        {
            get { return _meterDbm; }
            set { this.RaiseAndSetIfChanged(ref _meterDbm, value); }
        }

        double _lowSlope;
        public double LowSlope
        {
            get { return _lowSlope; }
            set { this.RaiseAndSetIfChanged(ref _lowSlope, value); }
        }

        double _lowIntercept;
        public double LowIntercept
        {
            get { return _lowIntercept; }
            set { this.RaiseAndSetIfChanged(ref _lowIntercept, value); }
        }

        double _highSlope;
        public double HighSlope
        {
            get { return _highSlope; }
            set { this.RaiseAndSetIfChanged(ref _highSlope, value); }
        }

        double _highIntercept;
        public double HighIntercept
        {
            get { return _highIntercept; }
            set { this.RaiseAndSetIfChanged(ref _highIntercept, value); }
        }

        bool _writeMtrTag;
        public bool WriteMtrTag
        {
            get { return _writeMtrTag; }
            set { this.RaiseAndSetIfChanged(ref _writeMtrTag, value); }
        }

        double _frequency;
        public double Frequency
        {
            get { return _frequency; }
            set { this.RaiseAndSetIfChanged(ref _frequency, value); }
        }

        double _power;
        public double Power
        {
            get { return _power; }
            set { this.RaiseAndSetIfChanged(ref _power, value); }
        }

        int _averages;
        public int Averages
        {
            get { return _averages; }
            set { this.RaiseAndSetIfChanged(ref _averages, value); }
        }

        double _offsets;
        public double Offsets
        {
            get { return _offsets; }
            set { this.RaiseAndSetIfChanged(ref _offsets, value); }
        }

        int _triggerDelay;
        public int TriggerDelay
        {
            get { return _triggerDelay; }
            set { this.RaiseAndSetIfChanged(ref _triggerDelay, value); }
        }

        int _triggerWidth;
        public int TriggerWidth
        {
            get { return _triggerWidth; }
            set { this.RaiseAndSetIfChanged(ref _triggerWidth, value); }
        }

        bool _pwrCalRunning;
        public bool PwrCalRunning
        {
            get { return _pwrCalRunning; }
            set { this.RaiseAndSetIfChanged(ref _pwrCalRunning, value); }
        }
        string _pwrCalBtnTxt;
        public string PwrCalBtnTxt
        {
            get { return _pwrCalBtnTxt; }
            set { this.RaiseAndSetIfChanged(ref _pwrCalBtnTxt, value); }
        }
        double _msPerStep;
        public double MsPerStep
        {
            get { return _msPerStep; }
            set { this.RaiseAndSetIfChanged(ref _msPerStep, value); }
        }

        string _resultsFile;
        public string ResultsFile
        {
            get { return _resultsFile; }
            set { this.RaiseAndSetIfChanged(ref _resultsFile, value); }
        }

        bool _skipCollectData;
        public bool SkipCollectData
        {
            get { return _skipCollectData; }
            set { this.RaiseAndSetIfChanged(ref _skipCollectData, value); }
        }

        bool _persistCalData;
        public bool PersistCalData
        {
            get { return _persistCalData; }
            set { this.RaiseAndSetIfChanged(ref _persistCalData, value); }
        }

        int _tempMeasPeriod;
        public int TempMeasPeriod
        {
            get { return _tempMeasPeriod; }
            set { this.RaiseAndSetIfChanged(ref _tempMeasPeriod, value); }
        }

        int _tempMeasTime;
        public int TempMeasTime
        {
            get { return _tempMeasTime; }
            set { this.RaiseAndSetIfChanged(ref _tempMeasTime, value); }
        }

        bool _tempCoeffRunning;
        public bool TempCoeffRunning
        {
            get { return _tempCoeffRunning; }
            set { this.RaiseAndSetIfChanged(ref _tempCoeffRunning, value); }
        }

        string _tempCoeffBtnText;
        public string TempCoeffBtnTxt
        {
            get { return _tempCoeffBtnText; }
            set { this.RaiseAndSetIfChanged(ref _tempCoeffBtnText, value); }
        }

        bool _updatePowerTable;
        public bool UpdatePowerTable
        {
            get { return _updatePowerTable; }
            set { this.RaiseAndSetIfChanged(ref _updatePowerTable, value); }
        }
    }
}
