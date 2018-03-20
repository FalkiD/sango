using System;
using System.Collections.ObjectModel;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Reactive.Linq;
using ReactiveUI;
using RFenergyUI.Views;
using Newtonsoft.Json;
using MathNet.Numerics;
using M2TestModule;
using Interfaces;

namespace RFenergyUI.ViewModels
{
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

            //Object stuff = MathNet.Numerics.LinearRegression.MultipleRegression.

            CmdInit = ReactiveCommand.CreateAsyncObservable(x => CmdInitRun());
            CmdInit.IsExecuting.ToProperty(this, x => x.IsIniting, out _isIniting);
            CmdInit.Subscribe(result => CmdDone(result));
            CmdInit.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdReadCw = ReactiveCommand.CreateAsyncObservable(x => CmdReadCwRun());
            CmdReadCw.IsExecuting.ToProperty(this, x => x.IsReading, out _isReading);
            CmdReadCw.Subscribe(result => CmdDone(result));
            CmdReadCw.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdReadPulsed = ReactiveCommand.CreateAsyncObservable(x => CmdRdPulsedRun());
            CmdReadPulsed.IsExecuting.ToProperty(this, x => x.IsReading, out _isReading);
            CmdReadPulsed.Subscribe(result => CmdDone(result));
            CmdReadPulsed.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdEnableOffset = ReactiveCommand.CreateAsyncObservable(x => CmdEnableOffsetRun());
            CmdEnableOffset.IsExecuting.ToProperty(this, x => x.IsOffseting, out _isOffseting);
            CmdEnableOffset.Subscribe(result => CmdDone(result));
            CmdEnableOffset.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdOffsets = ReactiveCommand.CreateAsyncObservable(x => CmdOffsetsRun(x));
            CmdOffsets.IsExecuting.ToProperty(this, x => x.IsOffseting, out _isOffseting);
            CmdOffsets.Subscribe(result => CmdDone(result));
            CmdOffsets.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdFreq = ReactiveCommand.CreateAsyncObservable(x => CmdFreqRun(x));
            CmdFreq.IsExecuting.ToProperty(this, x => x.IsFrqing, out _isFrqing);
            CmdFreq.Subscribe(result => CmdDone(result));
            CmdFreq.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdTriggerDelay = ReactiveCommand.CreateAsyncObservable(x => CmdTrigDlyRun(x));
            CmdTriggerDelay.IsExecuting.ToProperty(this, x => x.IsTrging, out _isTrging);
            CmdTriggerDelay.Subscribe(result => CmdDone(result));
            CmdTriggerDelay.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdTriggerWidth = ReactiveCommand.CreateAsyncObservable(x => CmdTrigWidthRun(x));
            CmdTriggerWidth.IsExecuting.ToProperty(this, x => x.IsTrging, out _isTrging);
            CmdTriggerWidth.Subscribe(result => CmdDone(result));
            CmdTriggerWidth.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdReadSNs = ReactiveCommand.CreateAsyncObservable(x => CmdReadSNsRun());
            CmdReadSNs.IsExecuting.ToProperty(this, x => x.IsExecuting, out _isExecuting);
            CmdReadSNs.Subscribe(result => CmdReadSNsDone(result));
            CmdReadSNs.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            // Power calibration routines
            CmdPwrCal = ReactiveCommand.CreateAsyncObservable(x => CmdPwrCalRun());
            CmdPwrCal.Subscribe(result => MainViewModel.MsgAppendLine(result));
            PwrCalRunning = false;
            PwrCalBtnTxt = STR_START_PWRCAL;
            CmdPwrCalArrow = ReactiveCommand.CreateAsyncObservable(x => CmdPwrCalArrowRun(x));
            CmdPwrCalArrow.Subscribe(result => MainViewModel.MsgAppendLine(result));

            CmdAverages = ReactiveCommand.CreateAsyncObservable(x => CmdAvgRun(x));
            CmdAverages.IsExecuting.ToProperty(this, x => x.IsAvging, out _isAvging);
            CmdAverages.Subscribe(result => CmdDone(result));
            CmdAverages.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdCouplerOffsets = ReactiveCommand.CreateAsyncObservable(x => CmdCouplerOffsetsRun());
            CmdCouplerOffsets.IsExecuting.ToProperty(this, x => x.IsCouplering, out _isCouplering);
            CmdCouplerOffsets.Subscribe(result => CmdDone(result));
            CmdCouplerOffsets.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdTempCoefficient = ReactiveCommand.CreateAsyncObservable(x => CmdTempCoefficientRun());
            CmdTempCoefficient.Subscribe(result => CmdDone(result));
            CmdTempCoefficient.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            // Meter cal
            CmdMtrCal = ReactiveCommand.CreateAsyncObservable(x => CmdMtrCalRun());
            CmdMtrCal.IsExecuting.ToProperty(this, x => x.IsMtrCaling, out _isMtrCaling);
            CmdMtrCal.Subscribe(result => CmdDone(result));
            CmdMtrCal.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));
            //CmdMtrBreakpointArrow = ReactiveCommand.CreateAsyncObservable(x => CmdMtrBreakpointArrowRun(x));
            //CmdMtrBreakpointArrow.Subscribe(result => MainViewModel.MsgAppendLine(result));

            CmdJsonToDriver = ReactiveCommand.CreateAsyncObservable(x => CmdJsonRun(true));
            CmdJsonToDriver.IsExecuting.ToProperty(this, x => x.IsJsoning, out _isJsoning);
            CmdJsonToDriver.Subscribe(result => CmdDone(result));
            CmdJsonToDriver.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdJsonFromDriver = ReactiveCommand.CreateAsyncObservable(x => CmdJsonRun(false));
            CmdJsonFromDriver.IsExecuting.ToProperty(this, x => x.IsJsoning, out _isJsoning);
            CmdJsonFromDriver.Subscribe(result => CmdDone(result));
            CmdJsonFromDriver.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CouplerFwdOffset = CouplerReflOffset = 0;

            // Set some defaults, still must press Enter to send to LadyBug
            Frequency = 2450;
            Averages = 200;
            PowerStepSize = 0.5;
            // Some items setup after window initialization has completed
            MeterBreakpoint = 500;
            LowSlope = 6.4;
            LowIntercept = 6.0;
            HighSlope = 7.6;
            HighIntercept = -2.0;

            SkipCollectData = false;
            TempMeasPeriod = 500;
            TempMeasTime = 30000;
            TempCoeffBtnTxt = STR_START_TMPCOEFF;
        }

        public void SetupHardware()
        {
            if (MainViewModel.ICmd.HwType == InstrumentInfo.InstrumentType.S4)
            {
                Offsets = 44.0;
                TargetStart = 40.0;
                PowerStart = 20.0;
                Compression = 3.0;
                PowerStop = 50.0;
                DacAFixed = 0xe00;
                DriverSN = "1";    // init to bogus number
            }
            else
            {
                Offsets = 54.34;
                TargetStart = 40.0;
                PowerStart = 2.76;          // dB for ~0xb0 start
                Compression = 2.0;
                PowerStop = 26.0;
            }

            // setup Visibility flags based on hardware type
            switch (MainViewModel.ICmd.HwType)
            {
                default:
                case InstrumentInfo.InstrumentType.M2:
                    M2Only = MainViewModel.TestPanel.M2Only = true;
                    S4Only = MainViewModel.TestPanel.S4Only = false;
                    X7Only = MainViewModel.TestPanel.X7Only = false;
                    break;
                case InstrumentInfo.InstrumentType.S4:
                    M2Only = MainViewModel.TestPanel.M2Only = false;
                    S4Only = MainViewModel.TestPanel.S4Only = true;
                    X7Only = MainViewModel.TestPanel.X7Only = false;
                    break;
                case InstrumentInfo.InstrumentType.X7:
                    M2Only = MainViewModel.TestPanel.M2Only = false;
                    S4Only = MainViewModel.TestPanel.S4Only = false;
                    X7Only = MainViewModel.TestPanel.X7Only = true;
                    break;
            }
        }

        // general use executing property helper
        public bool IsExecuting { get { return _isExecuting.Value; } }
        readonly ObservableAsPropertyHelper<bool> _isExecuting;

        // Called when any command finishes
        void CmdDone(string result)
        {
            if (result.Length > 0)
                MainViewModel.MsgAppendLine(result);
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
        /// 0dB = 0x80 (M2, 0x10 S4)
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
            if (InitCalData(wrk, ref fout, ref result) == 0)
                return; // Error

            double InputStepSize = PowerStepSize; // separate from PowerStepSize, S4 needs much bigger input steps
            if (MainViewModel.ICmd.HwType == InstrumentInfo.InstrumentType.S4)
                InputStepSize = 2.0;

            try
            {
                int MEAS_DELAY = 250; // power measurement delay
                bool inCompression = false;
                double dBmTarget = TargetStart;
                double tolerance = 0.05;
                int MAX_ITERATIONS = 80;
                int MIN_ADJUST = 1;
                double MAX_DBMOUT = 62.0;
                double MAX_POWER = -1.0;    // keep track of max
                double COMPRESSION_CHECK = DriverCal ? 45.0 : 50.0;  // don't check compression until above this power
                double TOP_END = 60.0;      // check compression at high end when not in tolerance

                double nextValue = PowerStart;
                if (SkipCollectData == false)
                    CalResults = new ObservableCollection<PowerCalData>();
                double lastValue = Double.NaN;
                double gain = Double.NaN;
                double maxGain = 0.0;
                double stepsize = InputStepSize; // PowerStepSize;
                double lastStepsize = stepsize;
                while (PwrCalRunning && nextValue <= PowerStop
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
                    System.Threading.Thread.Sleep(MEAS_DELAY);
                    double externalPwr = ReadExternal(dBmTarget);
                    if (externalPwr > MAX_POWER)
                        MAX_POWER = externalPwr;
                    if (externalPwr > MAX_DBMOUT)
                        break;

                    int iterations = 0;
                    bool converged = false;
                    bool high = true;   // enter binary search from high side
                    MonitorPa[] results = null;
                    PowerCalData caldata = null;
                    //if (externalPwr > (dBmTarget - PowerStepSize / 2) ||   // get as close as possible
                    if (externalPwr > dBmTarget ||   // get as close as possible
                        Math.Abs(externalPwr - dBmTarget) <= tolerance)
                    {
                        if (MainViewModel.ICmd.HwType == InstrumentInfo.InstrumentType.S4 &&
                                    dBmTarget > PowerStart)
                            stepsize = InputStepSize / 2.0;
                        do
                        {
                            if ((Math.Abs(externalPwr - dBmTarget) <= tolerance) ||
                                (externalPwr > COMPRESSION_CHECK &&
                                 CheckCompression(maxGain, externalPwr, nextValue, wrk)))
                            {
                                InCompressionOrOnTarget(wrk, ref result, ref results,
                                                        fout, ref caldata, ref lastValue,
                                                        nextValue, externalPwr,
                                                        COMPRESSION_CHECK, ref dBmTarget,
                                                        tolerance, ref stepsize, ref gain,
                                                        ref maxGain, ref converged,
                                                        ref inCompression);
                                lastStepsize = stepsize;    // save valid stepsize
                                break; // done or next target
                            }

                            double lastTry = nextValue;
                            GetNextTry(ref nextValue, ref high, ref stepsize,
                                       externalPwr, dBmTarget,
                                       lastTry, MIN_ADJUST);
                            status = SetCalPower(nextValue);
                            System.Threading.Thread.Sleep(MEAS_DELAY);
                            externalPwr = ReadExternal(dBmTarget);
                        } while (PwrCalRunning &&
                                    nextValue < PowerStop &&
                                    ++iterations < MAX_ITERATIONS);
                    }
                    else if(externalPwr > TOP_END)
                    {
                        // check compression even if not in tolerance at the top end.
                        // might never hit target
                        if(CheckCompression(maxGain, externalPwr, nextValue, wrk))
                        {
                            InCompressionDone(wrk, ref result, ref results,
                                              fout, ref caldata,
                                              nextValue, externalPwr,
                                              ref stepsize, ref gain,
                                              ref inCompression);
                        }
                    }

                    if (!converged && !inCompression)
                    {
                        System.Threading.Thread.Sleep(250);
                        if ((status = MainViewModel.ICmd.PaStatus(M2Cmd.PWR_ADC, ref results)) != 0)
                        {
                            result = string.Format(" PaStatus read failed, status:{0}, exit cal", status);
                            PwrCalRunning = false;
                            wrk.ReportProgress(0, result);
                            break;
                        }
                        result = SearchResult(nextValue, externalPwr, results[0].Forward,
                                              Temperature(results), Voltage(results),
                                              MaxCurrent(results), stepsize);
                        if (iterations >= MAX_ITERATIONS)
                            result += ", *ERROR*, exceeded max iterations";
                        wrk.ReportProgress(0, result);
                        WriteCalData(fout, result, MainViewModel.ICmd.DacFromDB(nextValue));
                        //if(dBmTarget > 50.0)
                        //    stepsize = lastStepsize;    // no convergence, restore last good stepsize
                    }
                    nextValue += stepsize;
                }
                result = ResetPower();
                if (result.Length > 0)
                    wrk.ReportProgress(0, result);

                // Show why we exited
                if (nextValue >= PowerStop)
                {
                    result = string.Format("Power cal stopped: target output >= Max({0})", PowerStop);
                    wrk.ReportProgress(0, result);
                }

                if (inCompression || SkipCollectData)
                {
                    if (UpdatePowerTable)
                        UpdateCalData(fout, wrk);
                    if (PersistCalData)
                        PersistCalResults(fout, wrk);
                }
                if (CalResults.Count > 0)
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
        /// Returns 0 on error, 1 if all Ok.
        /// On error, result will have length (error description)
        /// </summary>
        /// <param name="wrk"></param>
        /// <param name="fout"></param>
        /// <param name="result"></param>
        /// <returns></returns>
        int InitCalData(BackgroundWorker wrk, ref StreamWriter fout, ref string result)
        {
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

            // Restore cal data, driver data as necessary
        //// Read driver serial number & fill-in property
        //MainViewModel.DebugPanel.GetTag = "drsn";
        //MainViewModel.DebugPanel.CmdGetTag.Execute(null);
        //System.Threading.Thread.Sleep(200);




            string driverFile = string.Format("PowerCalResults{0}_Driver_{1}.json", Frequency, DriverSN);
            if (DriverCal)
                ResultsFile = driverFile;
            else
            {
                ResultsFile = string.Format("PowerCalResults{0}.json", Frequency);
                RestoreDriverGain(driverFile, wrk);
            }
            if (SkipCollectData)
                RestoreCalResults(ResultsFile, wrk);

            try
            {
                if (!SkipCollectData && SetupForCal((ushort)DacAFixed, ref result) != 0)
                {
                    wrk.ReportProgress(0, result);
                    wrk.ReportProgress(0, "Calibration aborted");
                    return 0;
                }
            }
            catch (Exception ex)
            {
                wrk.ReportProgress(0,
                    string.Format("Exception SetupForCal():{0}", ex.Message));
            }

            SetDutyCycleCompensation(false);
            return 1;
        }

        /// <summary>
        /// In compression or at target, process data & exit search loop
        /// </summary>
        void InCompressionOrOnTarget(BackgroundWorker wrk, ref string result, 
                                    ref MonitorPa[] results, StreamWriter fout,
                                    ref PowerCalData caldata,
                                    ref double lastValue, double nextValue, 
                                    double externalPwr, double COMPRESSION_CHECK,
                                    ref double dBmTarget, double tolerance,
                                    ref double stepsize, ref double gain,
                                    ref double maxGain,
                                    ref bool converged, ref bool inCompression)
        {
            // Update Pa status
            System.Threading.Thread.Sleep(250);
            int status;
            if ((status = MainViewModel.ICmd.PaStatus(M2Cmd.PWR_ADC, ref results)) != 0)
            {
                result = string.Format(" PaStatus read failed, status:{0}, exit cal", status);
                PwrCalRunning = false;
                wrk.ReportProgress(0, result);
                return;
            }
            caldata = new PowerCalData
            {
                IQDacMag = MainViewModel.ICmd.DacFromDB(nextValue),
                PowerDB = nextValue,
                Coupler = results[0].Forward,
                ExternaldBm = externalPwr,       // or target?
                Temperature = Temperature(results),
                Volts = Voltage(results),
                Amps = MaxCurrent(results)
            };
            CalResults.Add(caldata);
            if (!DriverCal && CalResults.Count == 1 && TargetStart > 40.0)
            {
                // fill-in the bottom of our table with the lowest value we can use.
                for (int tmp_idx = 0; tmp_idx < (TargetStart - 40.0) / PowerStepSize; ++tmp_idx)
                    CalResults.Add(caldata);
            }
            if (Math.Abs(externalPwr - dBmTarget) <= tolerance)
            {
                if (!Double.IsNaN(lastValue))
                {
                    stepsize = nextValue - lastValue;
                    gain = externalPwr - ReferencePower(nextValue, caldata.IQDacMag);
                    if (gain > maxGain && dBmTarget > 47.5) // ignore lower power gain
                        maxGain = gain;
                }
                lastValue = nextValue;
                WriteCalEntry(wrk, fout, false,
                              nextValue, externalPwr, caldata.Coupler,
                              caldata.Temperature, caldata.Volts, caldata.Amps,
                              stepsize, gain, caldata.IQDacMag);
                dBmTarget += PowerStepSize;
                converged = true;
                // Check compression too
                if (externalPwr > COMPRESSION_CHECK &&
                    CheckCompression(maxGain, externalPwr, nextValue, wrk))
                {
                    wrk.ReportProgress(0, "In compression, done.");
                    inCompression = true;
                }
                return;  // on to next target
            }
            else
            {
                // Not within tolerance but already in compression
                gain = externalPwr - ReferencePower(nextValue, caldata.IQDacMag); // hasn't been updated yet during binary search
                WriteCalEntry(wrk, fout, true,
                              nextValue, externalPwr, caldata.Coupler,
                              caldata.Temperature, caldata.Volts, caldata.Amps,
                              stepsize, gain, caldata.IQDacMag);
                wrk.ReportProgress(0, "In compression, done.");
                inCompression = true;
                return;    // in compression, done
            }
        }

        void InCompressionDone(BackgroundWorker wrk, ref string result,
                               ref MonitorPa[] results, StreamWriter fout,
                               ref PowerCalData caldata,
                               double nextValue, double externalPwr, 
                               ref double stepsize, ref double gain,
                               ref bool inCompression)
        {
            // In compression, done, but not within spec of target
            System.Threading.Thread.Sleep(250);
            int status;
            if ((status = MainViewModel.ICmd.PaStatus(M2Cmd.PWR_ADC, ref results)) != 0)
            {
                result = string.Format(" PaStatus read failed, status:{0}, exit cal", status);
                PwrCalRunning = false;
                wrk.ReportProgress(0, result);
                return;
            }
            caldata = new PowerCalData
            {
                IQDacMag = MainViewModel.ICmd.DacFromDB(nextValue),
                PowerDB = nextValue,
                Coupler = results[0].Forward,
                ExternaldBm = externalPwr,       // or target?
                Temperature = Temperature(results),
                Volts = Voltage(results),
                Amps = MaxCurrent(results)
            };
            CalResults.Add(caldata);
            gain = externalPwr - ReferencePower(nextValue, caldata.IQDacMag); // hasn't been updated yet during binary search
            WriteCalEntry(wrk, fout, true,
                          nextValue, externalPwr, caldata.Coupler,
                          caldata.Temperature, caldata.Volts, caldata.Amps,
                          stepsize, gain, caldata.IQDacMag);
            wrk.ReportProgress(0, "In compression, done.");
            inCompression = true;
        }

        /// <summary>
        /// Return 'nextValue' to try
        /// </summary>
        /// <returns>sets nextValue, dB in to try next
        /// sets 'high' boolean</returns>
        void GetNextTry(ref double nextValue, ref bool high,
                        ref double stepsize,
                        double externalPwr, 
                        double dBmTarget,
                        double lastTry, 
                        double MIN_ADJUST)
        {
            if (externalPwr > dBmTarget)
            {
                nextValue -= stepsize;
                if (nextValue == lastTry)
                    nextValue -= MIN_ADJUST;
                if (!high)
                    high = true;
            }
            else
            {
                nextValue += stepsize;
                if (nextValue == lastTry)
                    nextValue += MIN_ADJUST;
                if (high)
                    high = false;
            }
            if (stepsize > 0.05)
                stepsize /= 2.0;
        }

        void WriteCalEntry(BackgroundWorker wrk, StreamWriter fout, bool compression,
                            double nextValue, double externalPwr, 
                            double coupler, double temperature, double volts, 
                            double amps, double stepsize, double gain, int dac)
        {
            string result = "";
            if (MainViewModel.ICmd.HwType == InstrumentInfo.InstrumentType.S4)
                result = string.Format(" Cal Entry, dB:{0,6:f3}, POut:{1,5:f2}, Temp:{2,2:f0}, Amps:{3,5:f2}, Stepsize:{4:f2}, Gain:{5,5:f2}",
                                        nextValue,
                                        externalPwr,
                                        temperature,
                                        amps,
                                        stepsize, gain);
            else
                result = string.Format(" Cal Entry, dB:{0,6:f3}, POut:{1,5:f2}, CouplerFwd:{2,4:f0}, Temp:{3,2:f0}, Volts:{4,5:f2}, Amps:{5,5:f2}, Stepsize:{6:f2}, Gain:{7,5:f2}",
                                        nextValue,
                                        externalPwr,
                                        coupler,
                                        temperature,
                                        volts,
                                        amps,
                                        stepsize, gain);
            wrk.ReportProgress(0, result);
            WriteCalData(fout, result, dac);
        }

        string SearchResult(double nextValue, double externalPwr, double couplerFwd,
                            double temperature, double volts,
                            double current, double stepsize)
        {
            string result;
            if (MainViewModel.ICmd.HwType == InstrumentInfo.InstrumentType.S4)
                result = string.Format(" Searching, dB:{0,6:f3}, POut:{1:f2}, Temp:{2,2:f0}, Amps:{3,5:f2}, Stepsize:{4:f2}",
                                        nextValue,
                                        externalPwr,
                                        temperature,
                                        current,
                                        stepsize);
            else
                result = string.Format(" Searching, dB:{0,6:f3}, ExtdBm:{1:f2}, CouplerFwd:{2,4:f0}, Temp:{3,2:f0}, Volts:{4,5:f2}, Amps:{5,5:f2}, Stepsize:{6:f2}",
                                        nextValue,
                                        externalPwr,
                                        couplerFwd,
                                        temperature,
                                        volts,
                                        current,
                                        stepsize);
            return result;
        }

        /// <summary>
        /// Different values used depending on system type
        /// </summary>
        /// <param name="nextValue"></param>
        /// <param name="IQDacMag"></param>
        /// <returns></returns>
        double ReferencePower(double nextValue, int IQDacMag)
        {
            if (MainViewModel.ICmd.HwType == InstrumentInfo.InstrumentType.S4 && DriverGain != null)
            {
                bool maxDriver;
                return DriverOutput(IQDacMag, out maxDriver);
            }
            else return nextValue;
        }

        /// <summary>
        /// Search driver data to find driver output for specified dac value
        /// </summary>
        /// <param name="dacValue"></param>
        /// <returns>Driver output for specified dac value</returns>
        double DriverOutput(int dacValue, out bool maxDriver)
        {
            for(int k = 0; k < DriverGain.Count; ++k)
            {
                if (DriverGain[k].IQDacMag <= dacValue)
                {
                    maxDriver = false;
                    if (k == 0)
                        return DriverGain[k].ExternaldBm;
                    else if (k >= DriverGain.Count - 1)
                        return DriverGain[k - 1].ExternaldBm;

                    // linear for now...
                    double dacDelta = DriverGain[k - 1].IQDacMag - DriverGain[k].IQDacMag;
                    double dbmDelta = DriverGain[k].ExternaldBm - DriverGain[k - 1].ExternaldBm;
                    return DriverGain[k].ExternaldBm - (((dacValue - DriverGain[k].IQDacMag) / dacDelta) * dbmDelta);
                }
            }
            maxDriver = true;
            return DriverGain[DriverGain.Count - 1].ExternaldBm;
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
                List<PowerCalData> results = new List<PowerCalData>(CalResults);
                int status = MainViewModel.ICmd.WriteCalResults(UpdatePowerTable, PersistCalData, Frequency, results);
                if (status != 0)
                {
                    msg = string.Format(" Write CalResults failed, status:{0}", MainViewModel.IErr.ErrorDescription(status));
                    wnd.ReportProgress(0, msg);
                    fout.WriteLine(MainViewModel.Timestamp + msg);
                    return;
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

        void RestoreDriverGain(string driverFile, BackgroundWorker wnd)
        {
            string filename = "";
            try
            {
                filename = Environment.GetFolderPath(Environment.SpecialFolder.CommonDocuments) +
                    "\\" + driverFile;
                if (File.Exists(filename) == false)
                    return;
                StreamReader fin = new StreamReader(filename);
                if (fin != null)
                {
                    string json = fin.ReadToEnd();
                    fin.Close();
                    DriverGain = JsonConvert.DeserializeObject<ObservableCollection<PowerCalData>>(json);
                }
            }
            catch (Exception ex)
            {
                wnd.ReportProgress(0, string.Format("Exception reading DriverGain from JSON file{0}:{1}", filename, ex.Message));
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
            try
            {
                int status = MainViewModel.ICmd.PersistCalResults(Frequency);
                if (status != 0)
                {
                    msg = string.Format(" Persist CalResults failed, frequency:{0:f1} MHz, status:{1}", 
                                            Frequency, MainViewModel.IErr.ErrorDescription(status));
                    wnd.ReportProgress(0, msg);
                    fout.WriteLine(MainViewModel.Timestamp + msg);
                    return;
                }
                msg = string.Format(" Persisted CalResults {0:f1} MHz to 'PCn' tag in EEPROM.", Frequency);
                wnd.ReportProgress(0, msg);
                fout.WriteLine(MainViewModel.Timestamp + msg);
            }
            catch (Exception ex)
            {
                msg = string.Format(" Exception persisting CalResults to EEPROM tag PCn:{0}", ex.Message);
                wnd.ReportProgress(0, msg);
                fout.WriteLine(MainViewModel.Timestamp + msg);
            }
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

        readonly ObservableAsPropertyHelper<bool> _isIniting;
        public bool IsIniting { get { return _isIniting.Value; } }
        public ReactiveCommand<string> CmdInit { get; protected set; }
        IObservable<string> CmdInitRun()
        {
            return Observable.Start(() =>
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
                return result;
            });
        }

        readonly ObservableAsPropertyHelper<bool> _isReading;
        public bool IsReading { get { return _isReading.Value; } }
        public ReactiveCommand<string> CmdReadCw { get; protected set; }
        IObservable<string> CmdReadCwRun()
        {
            return Observable.Start(() =>
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
                return result;
            });
        }

        public ReactiveCommand<string> CmdReadPulsed { get; protected set; }
        IObservable<string> CmdRdPulsedRun()
        {
            return Observable.Start(() =>
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
                return result;
            });
        }

        readonly ObservableAsPropertyHelper<bool> _isOffseting;
        public bool IsOffseting { get { return _isOffseting.Value; } }
        public ReactiveCommand<string> CmdEnableOffset { get; protected set; }
        IObservable<string> CmdEnableOffsetRun()
        {
            return Observable.Start(() =>
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
                return result;
            });
        }

        public ReactiveCommand<string> CmdOffsets { get; protected set; }
        IObservable<string> CmdOffsetsRun(object text)
        {
            return Observable.Start(() =>
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
                                return string.Format("Offset out of range({0}) must be between 0 and 65", Offsets);
                            MainViewModel.IMeter.Offset = Offsets;
                            result = string.Format("Offsest set to {0}", Offsets);
                            double check = MainViewModel.IMeter.Offset;
                            result += string.Format(", read:{0:f1}", check);

                            CmdEnableOffsetRun();
                        }
                        else
                            return string.Format("Error, cannot convert '{0}' to a double", text.ToString());
                    }
                    else result = "MainViewModel.IMeter interface is null, can't execute anything";
                }
                catch (Exception ex)
                {
                    result = string.Format("Offsets exception:{0}", ex.Message);
                }
                return result;
            });
        }

        readonly ObservableAsPropertyHelper<bool> _isFrqing;
        public bool IsFrqing { get { return _isFrqing.Value; } }
        public ReactiveCommand<string> CmdFreq { get; protected set; }
        IObservable<string> CmdFreqRun(object text)
        {
            return Observable.Start(() =>
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
                                return string.Format("Frequency out of range({0}) must be between 2400 and 2500", value);
                            //Frequency = value;
                            MainViewModel.IMeter.SetFrequency(Frequency);
                            result = string.Format("LadyBug SetFrequency {0:f1} mHz", Frequency);
             result += "**Need Meter Freq Event to update UI**";
                        }
                        else
                            return string.Format("Error, cannot convert '{0}' to a double", text.ToString());
                    }
                    else result = "MainViewModel.IMeter interface is null, can't execute anything";
                }
                catch (Exception ex)
                {
                    result = string.Format("Set LadyBug frequency exception:{0}", ex.Message);
                }
                return result;
            });
        }

        readonly ObservableAsPropertyHelper<bool> _isTrging;
        public bool IsTrging { get { return _isTrging.Value; } }
        public ReactiveCommand<string> CmdTriggerDelay { get; protected set; }
        IObservable<string> CmdTrigDlyRun(object text)
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    int value;
                    if (int.TryParse(text.ToString(), out value))
                    {
                        //TriggerDelay = value;
                        MainViewModel.IMeter.TriggerInTimeout = TriggerDelay;
                        result = string.Format("TriggerInTimeout set to {0}", TriggerDelay);
            result += "**Need TriggerDelay Event to update UI**";
                    }
                    else
                        return string.Format("Error, cannot convert '{0}' to an int", text.ToString());
                }
                catch (Exception ex)
                {
                    result = string.Format("TriggerDelay exception:{0}", ex.Message);
                }
                return result;
            });
        }

        public ReactiveCommand<string> CmdTriggerWidth { get; protected set; }
        IObservable<string> CmdTrigWidthRun(object text)
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    int value;
                    if (int.TryParse(text.ToString(), out value))
                    {
                        //TriggerWidth = value;
                        MainViewModel.IMeter.TriggerInTimeout = TriggerWidth;
                        result = string.Format("TriggerInTimeout set to {0}", TriggerDelay);
               result += "**Need TriggerWidth Event to update UI**";
                    }
                    else
                        return string.Format("Error, cannot convert '{0}' to an int", text.ToString());
                }
                catch (Exception ex)
                {
                    result = string.Format("TriggerWidth exception:{0}", ex.Message);
                }
                return result;
            });
        }

        public ReactiveCommand<string> CmdReadSNs { get; protected set; }
        IObservable<string> CmdReadSNsRun()
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    string tag = "";
                    int status = MainViewModel.IDbg.GetTag("drsn", ref tag);
                    if (status == 0)
                    {
                        tag = tag.TrimEnd(new char[] { '>', '\n', '\r' });
                        string[] tmp = tag.Split(new char[] { '=' });
                        if(tmp.Length == 2)
                            return tmp[1];
                    }
                    else
                        result = "Required drsn tag not found";
                }
                catch (Exception ex)
                {
                    result = string.Format("CmdReadSNs exception:{0}", ex.Message);
                }
                return result;
            });
        }
        void CmdReadSNsDone(string result)
        {
            if (result.Length > 0)
                DriverSN = result;
        }

        readonly ObservableAsPropertyHelper<bool> _isAvging;
        public bool IsAvging { get { return _isAvging.Value; } }
        public ReactiveCommand<string> CmdAverages { get; protected set; }
        IObservable<string> CmdAvgRun(object text)
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    int value;
                    if (int.TryParse(text as string, out value))
                    {
                        MainViewModel.IMeter.SetAverages(value);
                        return "CmdAverages done";
                    }
                    else return string.Format("Can't convert {0} to integer", text.ToString());
                }
                catch (Exception ex)
                {
                    result = string.Format("CmdAverages exception:{0}", ex.Message);
                }
                return result;
            });
        }

        readonly ObservableAsPropertyHelper<bool> _isJsoning;
        public bool IsJsoning { get { return _isJsoning.Value; } }
        public ReactiveCommand<string> CmdJsonToDriver { get; protected set; }
        public ReactiveCommand<string> CmdJsonFromDriver { get; protected set; }
        IObservable<string> CmdJsonRun(bool toDriver)
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    if (MainViewModel.ICmd != null)
                    {
                        string filename = "";
                        try
                        {
                            if (DriverSN == "1")
                                throw new ApplicationException("Driver serial number required, read tag 'drsn'");
                            string driverFile = string.Format("PowerCalResults{0}_Driver_{1}.json", Frequency, DriverSN);
                            filename = Environment.GetFolderPath(Environment.SpecialFolder.CommonDocuments) +
                                "\\" + driverFile;
                            if (File.Exists(filename))
                            {
                                StreamReader fin = new StreamReader(filename);
                                if (fin != null)
                                {
                                    string json = fin.ReadToEnd();
                                    fin.Close();
                                    byte[] jsonData = System.Text.Encoding.ASCII.GetBytes(json);
                                    int status = MainViewModel.ICmd.WriteDriverCalData(Frequency, jsonData, -1);
                                    if (status == 0)
                                        result = "Driver caldata written.";
                                    else result = "DriverGain invalid or missing data";
                                }
                                else
                                    result = string.Format("Error reading DriverGain JSON file{0}", filename);
                            }
                            else
                                result = string.Format("DriverGain JSON file{0} not found", filename);
                        }
                        catch (Exception ex)
                        {
                            result = string.Format("Exception reading DriverGain JSON file{0}:{1}", filename, ex.Message);
                        }
                    }
                    else result = "MainViewModel.ICmd interface is null, can't execute anything";
                }
                catch (Exception ex)
                {
                    result = string.Format("Write json caldata exception:{0}", ex.Message);
                }
                return result;
            });
        }

        readonly ObservableAsPropertyHelper<bool> _isMtrCaling;
        public bool IsMtrCaling { get { return _isMtrCaling.Value; } }
        public ReactiveCommand<string> CmdMtrCal { get; protected set; }
        IObservable<string> CmdMtrCalRun()
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    if (MeterBreakpoint < MIN_METER_BREAKPOINT &&
                        MeterBreakpoint > MAX_METER_BREAKPOINT)
                    {
                        return string.Format("MeterBreakpont out of range({0}) must be between {1} and {2}",
                                              MeterBreakpoint, MIN_METER_BREAKPOINT, MAX_METER_BREAKPOINT);
                    }
                    if (MainViewModel.IDbg != null)
                    {
                        byte[] cmd = new byte[M2Cmd.MTR_CAL_DATA + 1];
                        cmd[0] = M2Cmd.CAL_MTR;
                        cmd[1] = M2Cmd.MTR_UPDATE_INUSE;
                        if (WriteMtrTag)
                            cmd[1] |= (byte)M2Cmd.MTR_UPDATE_EEPROM;
                        cmd[2] = (byte)((short)MeterBreakpoint & 0xff);
                        cmd[3] = (byte)(((short)MeterBreakpoint >> 8) & 0xff);
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
                return result;
            });
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

        readonly ObservableAsPropertyHelper<bool> _isCouplering;
        public bool IsCouplering { get { return _isCouplering.Value; } }
        public ReactiveCommand<string> CmdCouplerOffsets { get; protected set; }
        IObservable<string> CmdCouplerOffsetsRun()
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    int status = EnableChannels(false);
                    if (status != 0)
                    {
                        return string.Format(" Disable channels failed, status:{0}", MainViewModel.IErr.ErrorDescription(status));
                    }
                    System.Threading.Thread.Sleep(1000);

                    double fwd, refl;
                    fwd = refl = 0.0;
                    status = ReadCoupler(M2Cmd.PWR_RAW, ref fwd, ref refl);
                    if (status != 0)
                    {
                        return string.Format(" ReadCoupler failed, status:{0}", MainViewModel.IErr.ErrorDescription(status));
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
                    if (WriteFofRofTags)
                    {
                        // Write these values to binary tags FOF & ROF
                        short tmp = (short)((int)CouplerFwdOffset & 0x3fff);
                        if ((status = MainViewModel.IDbg.SetTag("FOF", BitConverter.GetBytes(tmp))) == 0)
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
                return result;
            });
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

        /// <summary>
        /// For S4:
        /// NO, just use it as starting DAC value. We'll program both
        /// Fix DAC A at the passed in value.
        /// Set to adjust only DAC B
        /// </summary>
        /// <param name="dacAValue"></param>
        int SetupForCal(ushort dacAValue, ref string result)
        {
            int status = 0;
            result = "";
            if (MainViewModel.ICmd.HwType == InstrumentInfo.InstrumentType.S4)
            {
                if (MainViewModel.TestPanel.PatternFile.Length == 0)
                {
                    result = "Missing pattern filename";
                    return 100;
                }
                if (DriverSN.Length == 0 || DriverSN == "1")
                {
                    result = "Driver serial number required for S4 calibration";
                    return 100;
                }

                string rsp = "";
                System.Threading.Thread.Sleep(150);
                MainViewModel.TestPanel.BiasOn =
                    MainViewModel.ICmd.BiasEnable(false);

                // This mode is the default & probably won't be changed by a user
                //
                //System.Threading.Thread.Sleep(150);
                //if ((status = MainViewModel.ICmd.RunCmd("fw 12 3 0 0 0\n", ref rsp)) != 0)
                //    result = "Error setting S4 VGA DAC mode:" + rsp;
                //else
                {
                    System.Threading.Thread.Sleep(150);
                    if ((status = MainViewModel.ICmd.RunCmd(string.Format("calpwr 0x17{0:x3}0\n", dacAValue), ref rsp)) != 0)
                        result = "Error setting S4 VGA DAC's:" + rsp;
                    else
                    {
                        System.Threading.Thread.Sleep(150);
                        string cmdline = "use 1\n";     // cal20us.ptf must be set as profile 1
                        if ((status = MainViewModel.ICmd.RunCmd(cmdline, ref rsp)) != 0)
                            result = "Error loading calibration pattern:" + rsp;
                        else
                        {
                            System.Threading.Thread.Sleep(150);
                            if ((status = MainViewModel.ICmd.RunCmd("trig ctrl 0x95 10\n", ref rsp)) != 0)
                                result = "Error triggering pattern:" + rsp;
                            else
                            {
                                System.Threading.Thread.Sleep(150);
                                MainViewModel.TestPanel.BiasOn =
                                    MainViewModel.ICmd.BiasEnable(true);
                                result = "S4 ready for power calibration";
                            }
                        }
                    }
                }
            }
            return status;
        }

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
            if (results.Length == 1)
                return (int)results[0].Temperature;

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
            if (results.Length == 1)
                return (int)results[0].Voltage;

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
            if (results.Length == 1)
                return results[0].Current;

            double maxAmps = Double.NegativeInfinity;
            for (int k = 0; k < results.Length; ++k)
            {
                if(results[k].Current > maxAmps)
                maxAmps = results[k].Current;
            }
            return maxAmps;
        }

        bool CheckCompression(double maxGain, double pOut, double pIn,
                                BackgroundWorker wrk)
        {
            if (maxGain > 0)
            {
                double gain = pOut - pIn;
                // For S4 lookup driver output power
                if (MainViewModel.ICmd.HwType == InstrumentInfo.InstrumentType.S4 && !DriverCal)
                {
                    bool maxDriver;
                    pIn = DriverOutput(MainViewModel.ICmd.DacFromDB(pIn), out maxDriver);
                    gain = pOut - pIn;
                    if (maxDriver)
                    {
                        wrk.ReportProgress(0, string.Format("*AtMaxDriverOutput* Gain:{0:f2}, MaxGain:{1:f2}, Compression:{2:f1}",
                                                gain, maxGain, (maxGain - gain)));
                    }
                }
                //if (pOut > 55.0)
                //    if (gain > 50)
                //        System.Diagnostics.Debug.WriteLine("AFU");
                //    wrk.ReportProgress(0, string.Format("Gain:{0:f2}, MaxGain:{1:f2}, Compression:{2:f1}", 
                //                            gain, maxGain, (maxGain - gain)));
                if (gain < maxGain && (maxGain - gain) >= Compression)
                    return true;
            }
            return false;
        }

        /// <summary>
        /// Argument only used when no hardware as dummy value
        /// </summary>
        /// <param name="dBmTarget"></param>
        /// <returns></returns>
        public double ReadExternal(double dBmTarget)
        {
            try
            {
                //System.Threading.Thread.Sleep(MEAS_DELAY);
                //return dBmTarget - 0.01;
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
                if (MainViewModel.ICmd.HwType == InstrumentInfo.InstrumentType.S4)
                    data += string.Format(", DacA:0x{0:x3}", DacAFixed);
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
            {
                if (MainViewModel.ICmd.HwType == InstrumentInfo.InstrumentType.S4)
                    fout.WriteLine(MainViewModel.Timestamp + line + string.Format(", VgaDacB:0x{0:x}", synDac));
                else
                    fout.WriteLine(MainViewModel.Timestamp + line + string.Format(", SynDac:0x{0:x}", synDac));
            }
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

        string ResetPower()
        {
            SetCalPower(PowerStart);

            string result = "";
            if (MainViewModel.ICmd.HwType == InstrumentInfo.InstrumentType.S4)
            {
                System.Threading.Thread.Sleep(150);
                MainViewModel.ICmd.BiasEnable(false);
                MainViewModel.TestPanel.BiasOn = false;
                //string rsp = "";
                //if (MainViewModel.ICmd.RunCmd("fw 6 1 0\n", ref rsp) != 0)
                //    result = "Error turning S4 BIAS OFF:" + rsp;
            }
            return result;
        }

        // props

        ObservableCollection<PowerCalData> _calResults;
        public ObservableCollection<PowerCalData> CalResults
        {
            get { return _calResults; }
            set { this.RaiseAndSetIfChanged(ref _calResults, value); }
        }

        ObservableCollection<PowerCalData> _driverGain;
        public ObservableCollection<PowerCalData> DriverGain
        {
            get { return _driverGain; }
            set { this.RaiseAndSetIfChanged(ref _driverGain, value); }
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

        string _driverSN;
        public string DriverSN
        {
            get { return _driverSN; }
            set { this.RaiseAndSetIfChanged(ref _driverSN, value); }
        }
        bool _driverCal;
        public bool DriverCal
        {
            get { return _driverCal; }
            set { this.RaiseAndSetIfChanged(ref _driverCal, value); }
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

        bool _invertTrigger;
        public bool InvertTrigger
        {
            get
            {
                if (MainViewModel.IMeter != null)
                {
                    _invertTrigger = MainViewModel.IMeter.TriggerInvert;
                }
                return _invertTrigger;
            }
            set
            {
                try
                {
                    if (MainViewModel.IMeter != null)
                    {
                        MainViewModel.IMeter.TriggerInvert = value;
                        MainViewModel.MsgAppendLine(string.Format("InvertTrigger set{0}", value ? "ON" : "OFF"));
                        this.RaiseAndSetIfChanged(ref _invertTrigger, value);
                    }
                    else
                        MainViewModel.MsgAppendLine("IMeter is null, can't set TriggerInvert");
                }
                catch (Exception ex)
                {
                    MainViewModel.MsgAppendLine(string.Format("TriggerInvert exception:{0}", ex.Message));
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

        int _dacAFixed;
        public int DacAFixed
        {
            get { return _dacAFixed; }
            set { this.RaiseAndSetIfChanged(ref _dacAFixed, value); }
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

        bool _m2only;
        public bool M2Only
        {
            get { return _m2only; }
            set { this.RaiseAndSetIfChanged(ref _m2only, value); }
        }

        bool _s4only;
        public bool S4Only
        {
            get { return _s4only; }
            set { this.RaiseAndSetIfChanged(ref _s4only, value); }
        }

        bool _x7only;
        public bool X7Only
        {
            get { return _x7only; }
            set { this.RaiseAndSetIfChanged(ref _x7only, value); }
        }
    }
}
