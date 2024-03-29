﻿using System;
using System.Collections.ObjectModel;
using System.Reactive.Linq;
using System.Windows;
using ReactiveUI;
using RFenergyUI.Views;
using RFenergyUI.Models;
using System.Threading.Tasks;
using System.ComponentModel;
using Interfaces;
using M2TestModule;

namespace RFenergyUI.ViewModels
{
    public class ChannelEntry
    {
        public int Number { get; set; }
        public bool IsSelected { get; set; }
    }

    public class TestViewModel : ReactiveObject
    {
        public const double VOLTS_PER_LSB = 0.001; // MCP4728, gain=2, 1mv LSB

        const string STR_START_SWEEP = "Start Sweep";
        const string STR_STOP_SWEEP = "Stop sweep";
        const string BIAS_ON = "Bias ON";
        const string BIAS_OFF = "Bias OFF";
        const string STR_HW_CONNECT_OK = " hardware connected Ok";

        TestView _testView;
        TestModel _model;
        bool _monitorBusy;
        static object _monitorLock = new object();
        bool _initializing;

        public TestViewModel(TestView view)
        {
            _monitorBusy = false;
            _testView = view;
            _model = new TestModel(this);
            _initializing = false;

            MainViewModel.TestPanel = this;

            LoopDelayMs = 1250;
            LoopReadings = false;
            DutyCycleCompensation = true; // default
            OpenLoopCompensation = true;

            BiasTitle = BIAS_ON;
            BiasOn = false;
            PatternFile = "cal20us.ptf";    // default cal file

            CmdBias = ReactiveCommand.CreateAsyncObservable(x => CmdBiasRun());
            CmdBias.IsExecuting.ToProperty(this, x => x.IsBiasing, out _isBiasing);
            CmdBias.Subscribe(result => CmdDone(result));
            CmdBias.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdConnect = ReactiveCommand.CreateAsyncObservable(x => CmdConnectRun());
            CmdConnect.IsExecuting.ToProperty(this, x => x.IsConnecting, out _isConnecting);
            CmdConnect.Subscribe(result => CmdConnectDone(result));
            CmdConnect.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdDisconnect = ReactiveCommand.CreateAsyncObservable(x => CmdDisconnectRun());
            CmdDisconnect.IsExecuting.ToProperty(this, x => x.IsDisconnecting, out _isDisconnecting);
            CmdDisconnect.Subscribe(result => CmdDone(result));
            CmdDisconnect.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdClrFault = ReactiveCommand.CreateAsyncObservable(x => CmdClrFaultRun());
            CmdClrFault.IsExecuting.ToProperty(this, x => x.IsClrFaulting, out _isClrFaulting);
            CmdClrFault.Subscribe(result => CmdDone(result));
            CmdClrFault.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdInfo = ReactiveCommand.CreateAsyncObservable(x => CmdInfoRun());
            CmdInfo.IsExecuting.ToProperty(this, x => x.IsInfoing, out _isInfoing);
            CmdInfo.Subscribe(result => CmdDone(result));
            CmdInfo.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdFrequency = ReactiveCommand.CreateAsyncObservable(x => CmdFrqRun(x));
            CmdFrequency.IsExecuting.ToProperty(this, x => x.IsFrqing, out _isFrqing);
            CmdFrequency.Subscribe(result => CmdDone(result));
            CmdFrequency.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));
            CmdFrqArrow = ReactiveCommand.CreateAsyncObservable(x => CmdFrqArrowRun(x));
            CmdFrqArrow.Subscribe(result => MainViewModel.MsgAppendLine(result));

            CmdPower = ReactiveCommand.CreateAsyncObservable(x => CmdPwrRun(x));
            CmdPower.IsExecuting.ToProperty(this, x => x.IsPowering, out _isPowering);
            CmdPower.Subscribe(result => CmdDone(result));
            CmdPower.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));
            CmdPwrArrow = ReactiveCommand.CreateAsyncObservable(x => CmdPwrArrowRun(x));
            CmdPwrArrow.Subscribe(result => MainViewModel.MsgAppendLine(result));

            CmdPwrInDb = ReactiveCommand.CreateAsyncObservable(x => CmdPwrInDbRun(x));
            CmdPwrInDb.IsExecuting.ToProperty(this, x => x.IsFrqing, out _isFrqing);
            CmdPwrInDb.Subscribe(result => CmdDone(result));
            CmdPwrInDb.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdPhase = ReactiveCommand.CreateAsyncObservable(x => CmdPhsRun());
            CmdPhase.Subscribe(result => MainViewModel.MsgAppendLine(result));
            CmdPhsArrow = ReactiveCommand.CreateAsyncObservable(x => CmdPhsArrowRun(x));
            CmdPhsArrow.Subscribe(result => MainViewModel.MsgAppendLine(result));

            CmdDutyCycle = ReactiveCommand.CreateAsyncObservable(x => CmdDutyCycleRun(x));
            CmdDutyCycle.Subscribe(result => MainViewModel.MsgAppendLine(result));
            CmdPwmDutyArrow = ReactiveCommand.CreateAsyncObservable(x => CmdPwmDutyArrowRun(x));
            CmdPwmDutyArrow.Subscribe(result => MainViewModel.MsgAppendLine(result));
            CmdPwmRate = ReactiveCommand.CreateAsyncObservable(x => CmdPwmRateRun(x));
            CmdPwmRate.Subscribe(result => MainViewModel.MsgAppendLine(result));
            CmdPwmTArrow = ReactiveCommand.CreateAsyncObservable(x => CmdPwmTArrowRun(x));
            CmdPwmTArrow.Subscribe(result => MainViewModel.MsgAppendLine(result));

            // Sweep buttons
            CmdFrqSweep = ReactiveCommand.CreateAsyncObservable(x => CmdFrqSweepRun());
            CmdFrqSweep.Subscribe(result => MainViewModel.MsgAppendLine(result));
            FrqSweepRunning = false;
            FrqSweepBtnTxt = STR_START_SWEEP;
            MsPerStep = 750;

            CmdPwrSweep = ReactiveCommand.CreateAsyncObservable(x => CmdPwrSweepRun());
            CmdPwrSweep.Subscribe(result => MainViewModel.MsgAppendLine(result));
            PwrSweepRunning = false;
            PwrSweepBtnTxt = STR_START_SWEEP;

            // Measure buttons
            CmdCouplerMeasure = ReactiveCommand.CreateAsyncObservable(x => CmdCouplerRun());
            CmdCouplerMeasure.Subscribe(result => MainViewModel.MsgAppendLine(result));
            //CmdZMonMeasure = ReactiveCommand.CreateAsyncObservable(x => CmdZMonMeasRun());
            //CmdZMonMeasure.Subscribe(result => MainViewModel.MsgAppendLine(result));


            CmdLoadPtnFile = ReactiveCommand.CreateAsyncObservable(x => CmdLoadPtnRun(x));
            CmdLoadPtnFile.Subscribe(result => MainViewModel.MsgAppendLine(result));

            CmdChoosePtnFile = ReactiveCommand.CreateAsyncObservable(x => CmdChoosePtnRun(x));
            CmdChoosePtnFile.Subscribe(result => MainViewModel.MsgAppendLine(result));

            CmdFwDir = ReactiveCommand.CreateAsyncObservable(x => CmdFwDirRun(x)); //, RxApp.TaskpoolScheduler);
            CmdFwDir.Subscribe(result => MainViewModel.MsgAppendLine(result));

            CmdTrig = ReactiveCommand.CreateAsyncObservable(x => CmdTrigRun(x));
            CmdTrig.Subscribe(result => MainViewModel.MsgAppendLine(result));

            CmdStopPtn = ReactiveCommand.CreateAsyncObservable(x => CmdStopPtnRun(x));
            CmdStopPtn.Subscribe(result => MainViewModel.MsgAppendLine(result));

            CmdMeas = ReactiveCommand.CreateAsyncObservable(x => CmdMeasRun(x));
            CmdMeas.Subscribe(result => MainViewModel.MsgAppendLine(result));

            //CmdTempComp = ReactiveCommand.CreateAsyncObservable(x => CmdTempCompRun(x));
            //CmdTempComp.Subscribe(result => MainViewModel.MsgAppendLine(result));

            FactoryMode = MainViewModel.FactoryMode;
        }

        /// <summary>
        /// Startup items after window has been created
        /// </summary>
        public void SetupHardware()
        {
            //PaVms = new ObservableCollection<PaViewModel>();
            //for (int channel = 1; channel < HW_CHANNELS + 1; ++channel)
            //{
            //    PaVms.Add(new PaViewModel
            //    {
            //        Channel = channel,
            //        ShowChannel = true
            //    });
            //}
            ChannelVms = new ObservableCollection<ChannelViewModel>();
            bool M2only = MainViewModel.ICmd.HwType == InstrumentInfo.InstrumentType.M2 ? true : false;
            bool S4only = MainViewModel.ICmd.HwType == InstrumentInfo.InstrumentType.S4 ? true : false;
            for (int channel = 1; channel < MainViewModel.ICmd.PaChannels + 1; ++channel)
            {
                ChannelVms.Add(new ChannelViewModel
                {
                    Number = channel,
                    IsSelected = true,
                    M2Only = M2only,
                    S4Only = S4only,
                    PhaseDacVm = new DacViewModel
                    {
                        Title = "Phase/S4_1A",
                        WhichDac = Dac.ePhaseTrim,
                        Channel = channel,
                        ShowChannel = true
                    },
                    GainDacVm = new DacViewModel
                    {
                        Title = "Gain/S4_1B",
                        WhichDac = Dac.eGainTrim,
                        Channel = channel,
                        ShowChannel = false
                    },
                    Bias1DacVm = new DacViewModel
                    {
                        Title = "Bias1/S4_2A",
                        WhichDac = Dac.eBias1,
                        Channel = channel,
                        ShowChannel = false
                    },
                    Bias2DacVm = new DacViewModel
                    {
                        Title = "Bias2/S4_2B",
                        WhichDac = Dac.eBias2,
                        Channel = channel,
                        ShowChannel = false
                    },
                    S4PaVm = new DacViewModel
                    {
                        Title = "S4 PA Bias",
                        WhichDac = Dac.eS4Pa,
                        Channel = channel,
                        ShowChannel = false
                    },
                    PaVm = new PaViewModel
                    {
                        Channel = channel,
                        ShowChannel = true
                    }
                });
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

            MainViewModel.ICmd.BiasEvent += new BooleanEvent(ICmd_BiasEvent);
            MainViewModel.ICmd.FrequencyEvent += new DoubleEvent(ICmd_FrequencyEvent);
            MainViewModel.ICmd.PowerEvent += new SetPowerEvent(ICmd_SetPowerEvent);
            MainViewModel.ICmd.CalDbEvent += new DoubleEvent(ICmd_CalDbEvent);
            //MainViewModel.IDbg.SetDbHandler += UpdateLastProgrammedDb;

            // Possible to change View property from ViewModel
            // not needed for setting static text from xaml though.
            //this.WhenAny(x => x.Channels, x => x.Value)
            //    .Subscribe(x => theControl.SetValue(AttachedObject.MyAttachedProperty, x);
        }

        // events from driver, **these are always on worker thread.

        void ICmd_BiasEvent(bool biasState, string msg)
        {
            _testView.Dispatcher.BeginInvoke((Action)(() =>
            {
                BiasOn = biasState;
            }));
        }
        void ICmd_FrequencyEvent(double megahertz, string msg)
        {
            _testView.Dispatcher.BeginInvoke((Action)(() =>
            {
                Frequency = megahertz;
                MainViewModel.CalPanel.Frequency = megahertz;
            }));
        }

        void ICmd_SetPowerEvent(double dbmOut, double db, string msg)
        {
            _testView.Dispatcher.BeginInvoke((Action)(() =>
            {
                Power = dbmOut;
                PwrInDb = db;
                MainViewModel.DebugPanel.PwrInDb = db;
            }));
        }

        void ICmd_CalDbEvent(double db, string msg)
        {
            _testView.Dispatcher.BeginInvoke((Action)(() =>
            {
                PwrInDb = db;
                MainViewModel.DebugPanel.PwrInDb = db;
            }));
        }

        // properties

        bool _factoryMode;
        public bool FactoryMode
        {
            get { return _factoryMode; }
            set { this.RaiseAndSetIfChanged(ref _factoryMode, value); }
        }

        bool _phaseVisible;
        public bool PhaseVisible
        {
            get { return _phaseVisible; }
            set { this.RaiseAndSetIfChanged(ref _phaseVisible, value); }
        }

        ObservableCollection<ChannelViewModel> _channelVms;
        public ObservableCollection<ChannelViewModel> ChannelVms
        {
            get { return _channelVms; }
            set { this.RaiseAndSetIfChanged(ref _channelVms, value); }
        }

        //ObservableCollection<PaViewModel> _paVms;
        //public ObservableCollection<PaViewModel> PaVms
        //{
        //    get { return _paVms; }
        //    set { this.RaiseAndSetIfChanged(ref _paVms, value); }
        //}

        double _pwrInDb;
        public double PwrInDb
        {
            get { return _pwrInDb; }
            set { this.RaiseAndSetIfChanged(ref _pwrInDb, value); }
        }

        double _frequency;
        public double Frequency
        {
            get { return _frequency; }
            set { this.RaiseAndSetIfChanged(ref _frequency, value); }
        }
        double _freqTop;
        public double FreqTop
        {
            get { return _freqTop; }
            set { this.RaiseAndSetIfChanged(ref _freqTop, value); }
        }
        double _freqStepSize;
        public double FreqStepSize
        {
            get { return _freqStepSize; }
            set { this.RaiseAndSetIfChanged(ref _freqStepSize, value); }
        }
        double _msPerStep;
        public double MsPerStep
        {
            get { return _msPerStep; }
            set { this.RaiseAndSetIfChanged(ref _msPerStep, value); }
        }
        // Frequency hi resolution mode
        bool _hires;
        public bool HiresMode
        {
            get { return _hires; }
            set
            {
                if(!_initializing)
                {
                    try
                    {
                        byte[] cmd = new byte[2];
                        cmd[0] = M2Cmd.RF_CTRL;
                        cmd[1] = (byte)(0x0f | (value ? 1 : 0));
                        byte[] rsp = null;
                        int status = MainViewModel.ICmd.RunCmd(cmd, ref rsp);
                        if (status == 0)
                        {
                            MainViewModel.MsgAppendLine(" Frequency hires mode toggle Ok");
                        }
                        else MainViewModel.MsgAppendLine(
                            string.Format(" Frequency hires mode toggle failed:{0}",
                            MainViewModel.IErr.ErrorDescription(status)));

                        // test it
                        cmd[0] = M2Cmd.ENABLE_RD;
                        status = MainViewModel.ICmd.RunCmd(cmd, ref rsp);
                    }
                    catch (Exception ex)
                    {
                        MainViewModel.MsgAppendLine(
                            string.Format(" Exception toggling hires mode:{0}",
                                                ex.Message));
                    }
                }
                this.RaiseAndSetIfChanged(ref _hires, value);
            }
        }

        bool _demo;
        public bool DemoMode
        {
            get { return _demo; }
            set
            {
                if (!_initializing)
                {
                    try
                    {
                        int status = MainViewModel.IDbg.SetTag("DM", (value ? "ON" : "OFF"));
                        if (status == 0)
                        {
                            MainViewModel.MsgAppendLine(" DemoMode set Ok");
                        }
                        else MainViewModel.MsgAppendLine(
                            string.Format(" DemoMode set failed:{0}",
                            MainViewModel.IErr.ErrorDescription(status)));
                    }
                    catch (Exception ex)
                    {
                        MainViewModel.MsgAppendLine(
                            string.Format(" Exception setting DemoMode:{0}",
                                                ex.Message));
                    }
                }
                this.RaiseAndSetIfChanged(ref _demo, value);
            }
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

        double _power;
        public double Power
        {
            get { return _power; }
            set { this.RaiseAndSetIfChanged(ref _power, value); }
        }
        double _powerTop;
        public double PowerTop
        {
            get { return _powerTop; }
            set { this.RaiseAndSetIfChanged(ref _powerTop, value); }
        }
        double _powerStepSize;
        public double PowerStepSize
        {
            get { return _powerStepSize; }
            set { this.RaiseAndSetIfChanged(ref _powerStepSize, value); }
        }

        double _phase;
        public double Phase
        {
            get { return _phase; }
            set { this.RaiseAndSetIfChanged(ref _phase, value); }
        }

        bool _biasOn;
        public bool BiasOn
        {
            get { return _biasOn; }
            set { this.RaiseAndSetIfChanged(ref _biasOn, value); }
        }

        string _biasTitle;
        public string BiasTitle
        {
            get { return _biasTitle; }
            set { this.RaiseAndSetIfChanged(ref _biasTitle, value); }
        }

        double _couplerFwd;
        public double CouplerFwd
        {
            get { return _couplerFwd; }
            set { this.RaiseAndSetIfChanged(ref _couplerFwd, value); }
        }

        double _couplerRefl;
        public double CouplerRefl
        {
            get { return _couplerRefl; }
            set { this.RaiseAndSetIfChanged(ref _couplerRefl, value); }
        }

        double _forwardPower;
        public double ForwardPower
        {
            get { return _forwardPower; }
            set { this.RaiseAndSetIfChanged(ref _forwardPower, value); }
        }

        double _reflectedPower;
        public double ReflectedPower
        {
            get { return _reflectedPower; }
            set { this.RaiseAndSetIfChanged(ref _reflectedPower, value); }
        }

        ushort _dutycycle;
        public ushort DutyCycle
        {
            get { return _dutycycle; }
            set { this.RaiseAndSetIfChanged(ref _dutycycle, value); }
        }

        bool _dcComp;
        public bool DutyCycleCompensation
        {
            get { return _dcComp; }
            set { this.RaiseAndSetIfChanged(ref _dcComp, value); }
        }

        bool _ambientComp;
        public bool AmbientCompensation
        {
            get { return _ambientComp; }
            set { this.RaiseAndSetIfChanged(ref _ambientComp, value); }
        }

        bool _openLoopComp;
        public bool OpenLoopCompensation
        {
            get { return _openLoopComp; }
            set { this.RaiseAndSetIfChanged(ref _openLoopComp, value); }
        }

        bool _powerLevelComp;
        public bool PowerLevelCompensation
        {
            get { return _powerLevelComp; }
            set { this.RaiseAndSetIfChanged(ref _powerLevelComp, value); }
        }

        int _pwmRate;
        public int PwmRate
        {
            get { return _pwmRate; }
            set { this.RaiseAndSetIfChanged(ref _pwmRate, value); }
        }

        bool _externalPwm;
        public bool ExternalPwm
        {
            get { return _externalPwm; }
            set { this.RaiseAndSetIfChanged(ref _externalPwm, value); }
        }

        double _adcDelayUs;
        public double AdcDelayUs
        {
            get { return _adcDelayUs; }
            set { this.RaiseAndSetIfChanged(ref _adcDelayUs, value); }
        }

        bool _loopReadings;
        public bool LoopReadings
        {
            get { return _loopReadings; }
            set
            {
                if (_testView.TestTimer != null)
                {
                    if (value)
                        _testView.TestTimer.Start();
                    else
                        _testView.TestTimer.Stop();
                }
                this.RaiseAndSetIfChanged(ref _loopReadings, value);
            }
        }

        int _loopDelayMs;
        public int LoopDelayMs
        {
            get { return _loopDelayMs; }
            set
            {
                if (_testView.TestTimer != null)
                {
                    bool reset = false;
                    if (LoopReadings)
                    {
                        reset = true;
                        _testView.TestTimer.Stop();
                    }
                    _testView.TestTimer.Interval = new TimeSpan(0, 0, 0, 0, value);
                    if (reset)
                        _testView.TestTimer.Start();
                }
                this.RaiseAndSetIfChanged(ref _loopDelayMs, value);
            }
        }

        // Various S4 properties

        /// <summary>
        /// Pattern filename (*.PAT)
        /// In the S4 MCU filesystem it's parsed into a binary
        /// *.PTF file.
        /// </summary>
        string _patternFile;
        public string PatternFile
        {
            get { return _patternFile; }
            set { this.RaiseAndSetIfChanged(ref _patternFile, value); }
        }

        /// <summary>
        /// Run a pattern using this trig command
        /// </summary>
        string _trigCommand;
        public string TrigCommand
        {
            get { return _trigCommand; }
            set { this.RaiseAndSetIfChanged(ref _trigCommand, value); }
        }


        /// <summary>
        /// Return this number of measurement results
        /// </summary>
        int _measCount;
        public int MeasCount
        {
            get { return _measCount; }
            set { this.RaiseAndSetIfChanged(ref _measCount, value); }
        }

        //// initialization
        //bool Initialized { get; set; }
        //public void Initialize()
        //{
        //    try
        //    {
        //        if (!Initialized)
        //        {
        //            Initialized = true; // Set it now since action is on another thread
        //            LoadValuesFromHardware();
        //            // You could unsubscribe event here.
        //        }
        //    }
        //    catch (Exception ex)
        //    {
        //        MainViewModel.MsgAppendLine(string.Format("Exception initializing values:{0}", ex.Message));
        //    }
        //}

        // commands

        // Called when any command finishes
        void CmdDone(string result)
        {
            if (result.Length > 0)
                MainViewModel.MsgAppendLine(result);
        }

        // helpers to get button state updated on UI thread from background thread
        readonly ObservableAsPropertyHelper<bool> _isBiasing;
        public bool IsBiasing { get { return _isBiasing.Value; } }
        public ReactiveCommand<string> CmdBias { get; protected set; }
        IObservable<string> CmdBiasRun()
        {
            // Observable.Start() starts the worker thread
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    MainViewModel.ICmd.BiasEnable(!BiasOn);
                }
                catch (Exception ex)
                {
                    result = string.Format("{0} BIAS Exception:{1}", MainViewModel.SelectedSystemName, ex.Message);
                }
                return result;
            });
        }

        readonly ObservableAsPropertyHelper<bool> _isClrFaulting;
        public bool IsClrFaulting { get { return _isClrFaulting.Value; } }
        public ReactiveCommand<string> CmdClrFault { get; protected set; }
        IObservable<string> CmdClrFaultRun()
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    // Fix this (hw independent)
                    if (MainViewModel.IDbg != null)
                    {
                        byte[] cmd = new byte[1];
                        cmd[0] = M2Cmd.CLR_STATUS;
                        byte[] data = null;
                        int status = MainViewModel.ICmd.RunCmd(cmd, ref data);
                        if (status == 0)
                            result = "ClrFault Ok\n";
                        else result = string.Format("ClrFault error:{0}", MainViewModel.IErr.ErrorDescription(status));
                    }
                    else result = "MainViewModel.IDbg interface is null, can't execute anything";
                }
                catch (Exception ex)
                {
                    result = string.Format("ClrFault exception:{0}", ex.Message);
                }
                return result;
            });
        }

        readonly ObservableAsPropertyHelper<bool> _isConnecting;
        public bool IsConnecting { get { return _isConnecting.Value; } }
        public ReactiveCommand<string> CmdConnect { get; protected set; }
        IObservable<string> CmdConnectRun()
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    if (MainViewModel.IDbg != null)
                    {
                        int status = MainViewModel.IDbg.Initialize(MainViewModel.MainLogFile);
                        if (status == 0)
                        {
                            result = MainViewModel.SelectedSystemName + STR_HW_CONNECT_OK;
                        }
                        else result = string.Format("{0} connect failed:{1}", MainViewModel.SelectedSystemName,
                                                                              MainViewModel.IErr.ErrorDescription(status));
                    }
                    else result = "MainViewModel.IDbg interface is null, can't execute anything";
                }
                catch (Exception ex)
                {
                    result = string.Format("Connect{0} Exception:{1}", MainViewModel.SelectedSystemName, ex.Message);
                }
                return result;
            });
        }
        void CmdConnectDone(string result)
        {
            if(result.Contains(STR_HW_CONNECT_OK))
                LoadValuesFromHardware(); // Fill-in panel with values from hardware
        }

        readonly ObservableAsPropertyHelper<bool> _isDisconnecting;
        public bool IsDisconnecting { get { return _isDisconnecting.Value; } }
        public ReactiveCommand<string> CmdDisconnect { get; protected set; }
        IObservable<string> CmdDisconnectRun()
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    if (MainViewModel.IDbg != null)
                    {
                        if (MainViewModel.TestPanel.LoopReadings)
                            MainViewModel.TestPanel.LoopReadings = false;
                        MainViewModel.IDbg.Close();
                        result = MainViewModel.SelectedSystemName + " hardware connection closed";
                    }
                    else result = "MainViewModel.IDbg interface is null, can't execute anything";
                }
                catch (Exception ex)
                {
                    result = string.Format("Disconnect{0} Exception:{1}", MainViewModel.SelectedSystemName, ex.Message);
                }
                return result;
            });
        }

        readonly ObservableAsPropertyHelper<bool> _isInfoing;
        public bool IsInfoing { get { return _isInfoing.Value; } }
        public ReactiveCommand<string> CmdInfo { get; protected set; }
        IObservable<string> CmdInfoRun()
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    if (MainViewModel.ICmd != null)
                    {
                        bool demoMode, hiresMode;
                        demoMode = hiresMode = false;
                        result = MainViewModel.ICmd.HardwareInfo(ref demoMode, ref hiresMode);
                    }
                    else result = "ICmd interface is null, can't execute anything";
                }
                catch (Exception ex)
                {
                    result = string.Format("Exception reading device info:{0}", ex.Message);
                }
                return result;
            });
        }

        readonly ObservableAsPropertyHelper<bool> _isFrqing;
        public bool IsFrqing { get { return _isFrqing.Value; } }
        public ReactiveCommand<string> CmdFrequency { get; protected set; }
        IObservable<string> CmdFrqRun(object text)
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    double value;
                    if (Double.TryParse(text.ToString(), out value))
                    {
                        if (value < 2400.0 || value > 2500.0)

                            return string.Format("Frequency out of range({0}) must be between 2400 and 2500", value);
                        if (MainViewModel.ICmd != null)
                        {
                            int frq = (int)(value * 65536.0);     // Q15.16 format
                            byte[] rsp = new byte[512];
                            rsp[0] = 0xFF;  // just flag error until fixup MMC returned status
                            int status = MainViewModel.ICmd.SetFrequency(value);
                            // TBD fix this up...
                            if (status == 0)
                            {
                                //if (MainViewModel.SelectedSystemName.StartsWith("MMC"))
                                //{
                                //    if (rsp[0] == 0x01)
                                //        result = " MMC Frequency Opcode Successful.";
                                //    else
                                //        result = string.Format(" MMC Frequency Opcode failed:0x{0}", rsp[0]); // MainViewModel.IErr.ErrorDescription(status));

                                //    List<string> results = new List<string>();
                                //    string more = string.Format("  {0:x02} {1:x02} {2:x02} {3:x02} {4:x02} {5:x02} {6:x02} {7:x02}",
                                //                            rsp[0], rsp[1], rsp[2], rsp[3], rsp[4], rsp[5], rsp[6], rsp[7]);

                                //    result += (", " + more);
                                //    //results.Add(string.Format("  {0:x02} {1:x02} {2:x02} {3:x02} {4:x02} {5:x02} {6:x02} {7:x02}",
                                //    //                        rsp[8], rsp[9], rsp[10], rsp[11], rsp[12], rsp[13], rsp[14], rsp[15]));

                                //}
                                //else
                                {
                                    UpdateLastProgrammedDb();
                                    result = " Set frequency Ok";
                                }
                            }
                            else result = string.Format(" Set Frequency failed:{0}", MainViewModel.IErr.ErrorDescription(status));
                        }
                        else result = "ICmd interface is null, can't execute anything";
                    }
                    else
                        result = string.Format("Error, cannot convert '{0}' to a double", text.ToString());
                }
                catch (Exception ex)
                {
                    result = string.Format("Set Frequency exception:{0}", ex.Message);
                }
                return result;
            });
        }
        public ReactiveCommand<string> CmdFrqArrow { get; protected set; }
        IObservable<string> CmdFrqArrowRun(object arrow)
        {
            return Observable.Return("");
        }

        readonly ObservableAsPropertyHelper<bool> _isPowering;
        public bool IsPowering { get { return _isPowering.Value; } }
        public ReactiveCommand<string> CmdPower { get; protected set; }
        IObservable<string> CmdPwrRun(object text)
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    double value;
                    if (Double.TryParse(text.ToString(), out value))
                    {
                        if (value < 30.0 || value > 63.0)
                        {
                            result = string.Format("Power out of range({0}) must be between 30 and 63", value);
                        }
                        else
                        {
                            //Power = value;
                            if (MainViewModel.ICmd != null)
                            {
                                int status = MainViewModel.ICmd.SetPower(value);
                                if (status == 0)
                                {
                                    result = " Set power Ok";
                                }
                                else result = string.Format(" Set power failed:{0}", MainViewModel.IErr.ErrorDescription(status));
                            }
                            else result = "ICmd interface is null, can't execute anything";
                        }
                    }
                    else
                        result = string.Format("Error, cannot convert '{0}' to a double", text.ToString());
                }
                catch (Exception ex)
                {
                    result = string.Format("Set Power exception:{0}", ex.Message);
                }
                return result;
            });
        }
        public ReactiveCommand<string> CmdPwrArrow { get; protected set; }
        IObservable<string> CmdPwrArrowRun(object arrow)
        {
            return Observable.Return("");
        }

        public ReactiveCommand<string> CmdLoadPtnFile { get; protected set; }
        IObservable<string> CmdLoadPtnRun(object text)
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    if (MainViewModel.ICmd != null)
                    {
                        string rsp = "";
                        int status = MainViewModel.ICmd.RunCmd(string.Format("loadpat {0} 0\n", PatternFile), ref rsp);
                        if (status == 0)
                        {
                            result = " S4 loadpat:" + rsp;
                        }
                        else result = string.Format(" S4 loadpat failed:{0}", MainViewModel.IErr.ErrorDescription(status));
                    }
                    else result = "ICmd interface is null, can't execute anything";
                }
                catch (Exception ex)
                {
                    result = string.Format("Load pattern file exception:{0}", ex.Message);
                }
                return result;
            });
        }

        public ReactiveCommand<string> CmdChoosePtnFile { get; protected set; }
        IObservable<string> CmdChoosePtnRun(object text)
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    if (MainViewModel.ICmd != null)
                    {
                        string rsp = "";
                        int status = MainViewModel.ICmd.RunCmd(string.Format("loadpat {0}\n"), ref rsp);
                        if (status == 0)
                        {
                            result = " S4 MCU DIR:" + rsp;
                        }
                        else result = string.Format(" S4 DIR failed:{0}", MainViewModel.IErr.ErrorDescription(status));
                    }
                    else result = "ICmd interface is null, can't execute anything";
                }
                catch (Exception ex)
                {
                    result = string.Format("Choose pattern file exception:{0}", ex.Message);
                }
                return result;
            });
        }

        public ReactiveCommand<string> CmdFwDir { get; protected set; }
        IObservable<string> CmdFwDirRun(object text)
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    if (MainViewModel.ICmd != null)
                    {
                        string rsp = "";
                        int status = MainViewModel.ICmd.RunCmd("dir\n", ref rsp);
                        if (status == 0)
                        {
                            result = " S4 MCU DIR:" + rsp;
                        }
                        else result = string.Format(" S4 DIR failed:{0}", MainViewModel.IErr.ErrorDescription(status));
                    }
                    else result = "ICmd interface is null, can't execute anything";
                }
                catch (Exception ex)
                {
                    result = string.Format("S4 filesystem DIR exception:{0}", ex.Message);
                }
                return result;
            });
        }

        public ReactiveCommand<string> CmdTrig { get; protected set; }
        IObservable<string> CmdTrigRun(object text)
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    if (MainViewModel.ICmd != null)
                    {
                        string rsp = "";
                        int status = MainViewModel.ICmd.RunCmd(text.ToString() + "\n", ref rsp);
                        if (status == 0)
                        {
                            result = string.Format(" S4 {0}:{1}", text.ToString(), rsp);
                        }
                        else result = string.Format(" S4 {0} failed:{1}", text.ToString(), MainViewModel.IErr.ErrorDescription(status));
                    }
                    else result = "ICmd interface is null, can't execute anything";
                }
                catch (Exception ex)
                {
                    result = string.Format("S4 trig command exception:{0}", ex.Message);
                }
                return result;
            });
        }

        public ReactiveCommand<string> CmdStopPtn { get; protected set; }
        IObservable<string> CmdStopPtnRun(object text)
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    if (MainViewModel.ICmd != null)
                    {
                        string rsp = "";
                        int status = MainViewModel.ICmd.RunCmd("trig ctrl 0x81\n", ref rsp);
                        if (status == 0)
                        {
                            result = string.Format(" S4 trig ctrl 0x81:{0}", rsp);
                        }
                        else result = string.Format(" S4 trig ctrl 0x81 failed:{0}", MainViewModel.IErr.ErrorDescription(status));
                    }
                    else result = "ICmd interface is null, can't execute anything";
                }
                catch (Exception ex)
                {
                    result = string.Format("S4 stop ptn(trig ctrl 0x81) exception:{0}", ex.Message);
                }
                return result;
            });
        }

        public ReactiveCommand<string> CmdMeas { get; protected set; }
        IObservable<string> CmdMeasRun(object text)
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    if (MainViewModel.ICmd != null)
                    {
                        string rsp = "";
                        int status = MainViewModel.ICmd.RunCmd(text.ToString() + "\n", ref rsp);
                        if (status == 0)
                        {
                            result = string.Format(" S4 {0}:{1}", text.ToString(), rsp);
                        }
                        else result = string.Format(" S4 {0} failed:{1}", text.ToString(), MainViewModel.IErr.ErrorDescription(status));
                    }
                    else result = "ICmd interface is null, can't execute anything";
                }
                catch (Exception ex)
                {
                    result = string.Format("S4 MEAS exception:{0}", ex.Message);
                }
                return result;
            });
        }

        public ReactiveCommand<string> CmdPwrInDb { get; protected set; }
        IObservable<string> CmdPwrInDbRun(object text)
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    double value;
                    if (Double.TryParse(text.ToString(), out value))
                    {
                        if (value < 0.0 || value > 45.0)
                            result = string.Format("Power out of range({0}) must be between 0 and 45 dB", value);
                        //PwrInDb = value;
                        int status;
                        if ((status = MainViewModel.CalPanel.SetCalPower(value)) == 0)
                            result = " Set PwrInDb Ok";
                        else result = string.Format(" Set PwrInDb failed:{0}", MainViewModel.IErr.ErrorDescription(status));
                    }
                    else
                        result = string.Format("Error, cannot convert '{0}' to a double", text.ToString());
                }
                catch (Exception ex)
                {
                    result = string.Format("Set PwrInDb exception:{0}", ex.Message);
                }
                return result;
            });
        }

        public ReactiveCommand<string> CmdPhase { get; protected set; }
        IObservable<string> CmdPhsRun()
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    if (MainViewModel.ICmd != null)
                    {
                        int pwr = (int)(Phase * 256.0);     // Q7.8 format
                        byte[] cmd = new byte[3];
                        cmd[0] = M2Cmd.PHASE;
                        cmd[1] = (byte)(pwr & 0xff);
                        cmd[2] = (byte)((pwr >> 8) & 0xff);
                        byte[] rsp = null;
                        int status = MainViewModel.ICmd.RunCmd(cmd, ref rsp);
                        if (status == 0)
                            result = " Set phase Ok";
                        else result = string.Format(" Set phase failed:{0}", MainViewModel.IErr.ErrorDescription(status));
                    }
                    else result = "ICmd interface is null, can't execute anything";
                }
                catch (Exception ex)
                {
                    result = string.Format("Set Phase exception:{0}", ex.Message);
                }
                return result;
            });
        }
        public ReactiveCommand<string> CmdPhsArrow { get; protected set; }
        IObservable<string> CmdPhsArrowRun(object arrow)
        {
            return Observable.Return("");
        }

        void UpdateLastProgrammedDb()
        {
            try
            {
                double dB = 0.0;
                int status = MainViewModel.ICmd.LastProgrammedDb(ref dB);
                if (status == 0)
                {
                    MainViewModel.DebugPanel.PwrInDb = dB;
                    PwrInDb = dB;
                }
                else MainViewModel.MsgAppendLine(string.Format(" UpdateLastDb error:{0}", MainViewModel.IErr.ErrorDescription(status)));
            }
            catch (Exception ex)
            {
                MainViewModel.MsgAppendLine(string.Format(" UpdateLastDb exception:{0}", ex.Message));
            }
        }

        /// <summary>
        /// Send PWM command after proeprties have been updated
        /// All exceptions handled by callers
        /// </summary>
        /// <returns></returns>
        IObservable<string> DoPwm()
        {
            return Observable.Start(() =>
            {
                string result = "";
                if (MainViewModel.ICmd != null)
                {
                    int status = MainViewModel.ICmd.SetPwm(DutyCycle, PwmRate, DutyCycle != 0, ExternalPwm);
                    if (status == 0)
                    {
                        UpdateLastProgrammedDb();
                        result = " Set PWM Ok";
                    }
                    else result = string.Format(" Set PWM failed:{0}", MainViewModel.IErr.ErrorDescription(status));
                }
                else result = "ICmd interface is null, can't execute anything";
                return result;
            });
        }
        public ReactiveCommand<string> CmdDutyCycle { get; protected set; }
        IObservable<string> CmdDutyCycleRun(object text)
        {
            string result = "";
            try
            {
                ushort value;
                if (ushort.TryParse(text.ToString(), out value))
                {
                    if (value < 1 || value > 100)
                        return Observable.Return(string.Format("DutyCycla out of range({0}) must be between 1 and 100", value));
                    DutyCycle = value;
                    return DoPwm();
                }
                else return Observable.Return(string.Format("Error, cannot convert '{0}' to a ushort", text.ToString()));
            }
            catch (Exception ex)
            {
                result = string.Format("Set DutyCycle exception:{0}", ex.Message);
            }
            return Observable.Return(result);
        }
        public ReactiveCommand<string> CmdPwmDutyArrow { get; protected set; }
        IObservable<string> CmdPwmDutyArrowRun(object arrow)
        {
            return Observable.Return("");
        }

        public ReactiveCommand<string> CmdPwmRate { get; protected set; }
        IObservable<string> CmdPwmRateRun(object text)
        {
            string result = "";
            try
            {
                int value;
                if (int.TryParse(text.ToString(), out value))
                {
                    if (value > 650000 || value < 1)
                        return Observable.Return(string.Format("PwmRate(Hz) out of range({0}) must be between 1 and 65000 (Hz)", value));
                    PwmRate = value;
                    return DoPwm();
                }
                else return Observable.Return(string.Format("Error, cannot convert '{0}' to an int", text.ToString()));
            }
            catch (Exception ex)
            {
                result = string.Format("Set PwmRate(Hz) exception:{0}", ex.Message);
            }
            return Observable.Return(result);
        }
        public ReactiveCommand<string> CmdPwmTArrow { get; protected set; }
        IObservable<string> CmdPwmTArrowRun(object arrow)
        {
            return Observable.Return("");
        }

        // Sweep button properties, run funcs
        bool _frqSweepRunning;
        public bool FrqSweepRunning
        {
            get { return _frqSweepRunning; }
            set { this.RaiseAndSetIfChanged(ref _frqSweepRunning, value); }
        }
        string _frqSweepBtnTxt;
        public string FrqSweepBtnTxt
        {
            get { return _frqSweepBtnTxt; }
            set { this.RaiseAndSetIfChanged(ref _frqSweepBtnTxt, value); }
        }
        public ReactiveCommand<string> CmdFrqSweep { get; protected set; }
        IObservable<string> CmdFrqSweepRun()
        {
            string result = "";
            try
            {
                if (MainViewModel.ICmd != null)
                {
                    if (FrqSweepRunning)
                    {
                        FrqSweepBtnTxt = STR_START_SWEEP;
                        FrqSweepRunning = false;
                        result = " Frequency sweep stopped";
                    }
                    else
                    {
                        FrqSweepBtnTxt = STR_STOP_SWEEP;
                        FrqSweepRunning = true;
                        BackgroundWorker frqworker = new BackgroundWorker();
                        frqworker.WorkerReportsProgress = true;
                        frqworker.DoWork += freq_DoWork;
                        frqworker.ProgressChanged += freq_ProgressChanged;
                        frqworker.RunWorkerCompleted += freq_RunWorkerCompleted;
                        frqworker.RunWorkerAsync(1000000);
                    }
                    result = string.Format(" begin freq, start:{0:f1}, end:{1:f1}, step:{2:f1}", Frequency, FreqTop, FreqStepSize);
                }
                else result = "ICmd interface is null, can't execute anything";
            }
            catch (Exception ex)
            {
                result = string.Format("Start frequency sweep exception:{0}", ex.Message);
            }
            return Observable.Return(result);
        }

        void freq_DoWork(object sender, DoWorkEventArgs e)
        {
            double startFreq = Frequency;
            int steps = (int)((FreqTop - Frequency + 0.5) / FreqStepSize);
            double frq;
            for (int j = 0; j < steps; ++j)
            {
                frq = Frequency + (j * FreqStepSize);
                int status = MainViewModel.ICmd.SetFrequency(frq);
                string msg;
                if(status != 0)
                {
                    msg = string.Format("Set frequency {0} Hz failed, status:{1}, exit sweep", frq, status);
                    FrqSweepRunning = false;
                }
                else
                {
                    msg = string.Format("Set frequency {0} Hz, step {1} of {2} Ok", frq, j+1, steps);
                }
                (sender as BackgroundWorker).ReportProgress(0, msg);
                if (FrqSweepRunning == false)
                    break;
                if(MsPerStep >  0)
                    System.Threading.Thread.Sleep((int)MsPerStep);
            }
            e.Result = 0;
            MainViewModel.ICmd.SetFrequency(startFreq);
        }

        void freq_ProgressChanged(object sender, ProgressChangedEventArgs e)
        {
            if (e.UserState != null)
                MainViewModel.MsgAppendLine((string)e.UserState);
        }

        void freq_RunWorkerCompleted(object sender, RunWorkerCompletedEventArgs e)
        {
            MainViewModel.MsgAppendLine("Frequency sweep done");
        }
        // End of frequency sweep


        bool _pwrSweepRunning;
        public bool PwrSweepRunning
        {
            get { return _pwrSweepRunning; }
            set { this.RaiseAndSetIfChanged(ref _pwrSweepRunning, value); }
        }
        string _pwrSweepBtnTxt;
        public string PwrSweepBtnTxt
        {
            get { return _pwrSweepBtnTxt; }
            set { this.RaiseAndSetIfChanged(ref _pwrSweepBtnTxt, value); }
        }
        public ReactiveCommand<string> CmdPwrSweep { get; protected set; }
        IObservable<string> CmdPwrSweepRun()
        {
            string result = "";
            try
            {
                if (MainViewModel.ICmd != null)
                {
                    if (PwrSweepRunning)
                    {
                        PwrSweepBtnTxt = STR_START_SWEEP;
                        PwrSweepRunning = false;
                        result = " Power sweep stopped";
                    }
                    else
                    {
                        PwrSweepBtnTxt = STR_STOP_SWEEP;
                        PwrSweepRunning = true;
                        BackgroundWorker worker = new BackgroundWorker();
                        worker.WorkerReportsProgress = true;
                        worker.DoWork += pwr_DoWork;
                        worker.ProgressChanged += pwr_ProgressChanged;
                        worker.RunWorkerCompleted += pwr_RunWorkerCompleted;
                        worker.RunWorkerAsync(1000000);
                        result = string.Format(" begin power sweep, start:{0:f1}, end:{1:f1}, stepsize:{2:f1}", Power, PowerTop, PowerStepSize);
                    }
                }
                else result = "ICmd interface is null, can't execute anything";
            }
            catch (Exception ex)
            {
                result = string.Format("Start power sweep exception:{0}", ex.Message);
            }
            return Observable.Return(result);
        }
        void pwr_DoWork(object sender, DoWorkEventArgs e)
        {
            double startPower = Power;
            int steps = (int)((PowerTop - Power + 0.05) / PowerStepSize);
            double dbm;
            for (int j = 0; j < steps; ++j)
            {
                dbm = Power + (j * PowerStepSize);
                int status = MainViewModel.ICmd.SetPower(dbm);
                string msg;
                if (status != 0)
                {
                    msg = string.Format("Set power {0:f1} dBm failed, status:{1}, exit sweep", dbm, status);
                    PwrSweepRunning = false;
                }
                else
                {
                    msg = string.Format("Set power {0:f1} dBm, step {1} of {2} Ok", dbm, j + 1, steps);
                }
                (sender as BackgroundWorker).ReportProgress(0, msg);
                if (PwrSweepRunning == false)
                    break;
                if (MsPerStep > 0)
                    System.Threading.Thread.Sleep((int)MsPerStep);
            }
            e.Result = 0;
            MainViewModel.ICmd.SetPower(startPower);
        }

        void pwr_ProgressChanged(object sender, ProgressChangedEventArgs e)
        {
            if (e.UserState != null)
                MainViewModel.MsgAppendLine((string)e.UserState);
        }

        void pwr_RunWorkerCompleted(object sender, RunWorkerCompletedEventArgs e)
        {
            MainViewModel.MsgAppendLine("Power sweep done");
        }
        // End of power sweep

        public ReactiveCommand<string> CmdCouplerMeasure { get; protected set; }
        IObservable<string> CmdCouplerRun()
        {
            string result = "";
            try
            {
                if (MainViewModel.ICmd != null)
                {
                    double forward, reflected;
                    forward = reflected = 0.0;
                    int status = MainViewModel.ICmd.CouplerPower(M2Cmd.PWR_DBM, ref forward, ref reflected);
                    if(status == 0)
                    {
                        CouplerFwd = forward;
                        CouplerRefl = reflected;
                        result = string.Format(" Coupler Fwd:{0:f1} dBm, Refl:{1:f1} dBm", 
                                                forward, 
                                                reflected);
                    }
                    else
                        result = string.Format(" Read coupler failed:{0}", MainViewModel.IErr.ErrorDescription(status));
                }
                else result = "ICmd interface is null, can't execute anything";
            }
            catch (Exception ex)
            {
                result = string.Format("Read coupler exception:{0}", ex.Message);
            }
            return Observable.Return(result);
        }

        //public ReactiveCommand<string> CmdZMonMeasure { get; protected set; }
        //IObservable<string> CmdZMonMeasRun()
        //{
        //    string result = "";
        //    try
        //    {
        //        if (MainViewModel.ICmd != null)
        //        {
        //            double forward, reflected;
        //            forward = reflected = 0.0;
        //            int status = MainViewModel.ICmd.ZMonPower(ref forward, ref reflected);
        //            if (status == 0)
        //                result = string.Format(" ZMon Fwd:{0:f0}, ZMon Refl:{1:f0}", forward, reflected);
        //            else
        //                result = string.Format(" Read ZMon failed:{0}", MainViewModel.IErr.ErrorDescription(status));
        //        }
        //        else result = "ICmd interface is null, can't execute anything";
        //    }
        //    catch (Exception ex)
        //    {
        //        result = string.Format("Start power sweep exception:{0}", ex.Message);
        //    }
        //    return Observable.Return(result);
        //}

        //public ReactiveCommand<string> CmdTempComp { get; protected set; }
        //IObservable<string> CmdTempCompRun(object text)
        //{
        //    string result = "";
        //    try
        //    {
        //        int value;
        //        if (int.TryParse(text.ToString(), out value))
        //        {
        //            if (value < 0 || value > 2)
        //                return Observable.Return(string.Format("Invalid temp comp value({0}) must be between 0 and 2", value));
        //            TemperatureCompensation = value;
        //            int status;
        //            if ((status = MainViewModel.ICmd.TemperatureCompensation(value)) == 0)
        //                result = " Set TempComp Ok";
        //            else result = string.Format(" Set TempComp failed:{0}", MainViewModel.IErr.ErrorDescription(status));
        //        }
        //        else
        //            return Observable.Return(string.Format("Error, cannot convert '{0}' to an integer", text.ToString()));
        //    }
        //    catch (Exception ex)
        //    {
        //        result = string.Format("Set TempComp exception:{0}", ex.Message);
        //    }
        //    return Observable.Return(result);
        //}

        // Timer from UI thread to update readings
        public void TimerTick()
        {
            // Crude place to initialize settings at startup.
            // If we have not read the device EEPROM do it.
            //if (_model != null && _model.Initialized == false)
            //    _model.LastProgrammedValues();

            if(_monitorBusy)
                return;

            lock (_monitorLock) 
            {
                _monitorBusy = true;
                DoReadings();
            }
        }

        /// <summary>
        /// Monitor PA's on a timer. Read data on a background thread,
        /// update ViewModel's on return.
        /// </summary>
        MonitorPa[] _results;
        async void DoReadings()
        {
            if(_results == null)
                _results = new MonitorPa[MainViewModel.ICmd.PaChannels];

            MonitorPa results = await Task.Run(() => ReadData());
            if (results.ErrorMessage.Length > 0)
                MainViewModel.MsgAppendLine(results.ErrorMessage);
            else
            {
                // back on UI thread, update ViewModels with _results
                for (int channel = 1; channel <= MainViewModel.ICmd.PaChannels; ++channel)
                {
                    ChannelVms[channel - 1].PaVm.Current = _results[channel - 1].Current;
                    ChannelVms[channel - 1].PaVm.Voltage = _results[channel - 1].Voltage;
                    ChannelVms[channel - 1].PaVm.Temperature = _results[channel - 1].Temperature;
                    ChannelVms[channel - 1].PaVm.IDrv = _results[channel - 1].IDrv;
                }
                CouplerFwd = _results[0].Forward;
                CouplerRefl = _results[0].Reflected;
                if(MainViewModel.CalPanel != null)
                {
                    MainViewModel.CalPanel.MeterDbm = CouplerFwd;
                }
                //if(MainViewModel.DebugPanel != null)
                //{
                //    MainViewModel.DebugPanel.UpdateValues();
                //}
            }
            _monitorBusy = false;
        }

        /// <summary>
        /// MonitorPa background func to read hardware values
        /// on a timer
        /// </summary>
        /// <returns></returns>
        MonitorPa ReadData()
        {
            MonitorPa results = new MonitorPa();
            results.ErrorMessage = "";
            try
            {
                if (MainViewModel.ICmd != null)
                {
                    int status = MainViewModel.ICmd.PaStatus(M2Cmd.PWR_DBM, ref _results);
                    if(status != 0)
                        results.ErrorMessage = string.Format(" RF_STATUS failed:{1}", MainViewModel.IErr.ErrorDescription(status));
                }
                else results.ErrorMessage = "ICmd interface is null, can't read anything";
            }
            catch (Exception ex)
            {
                results.ErrorMessage = string.Format("Read ADC's exception:{0}", ex.Message);
            }
            return results;
        }



        /// <summary>
        /// Start a background task to read everything from the hardware,
        /// done at startup to fill-in all the controls
        /// </summary>
        async void LoadValuesFromHardware()
        {
            RfSettings settings = await Task.Run(() => ReadInitialSettings());
            if (settings.ErrorMessage.Length > 0)
                MainViewModel.MsgAppendLine(settings.ErrorMessage);
            else
            {
                // back on UI thread, update ViewModel with settings
                Frequency = settings.Frequency;
                MainViewModel.CalPanel.Frequency = settings.Frequency;
                Power = settings.Power;
                Phase = settings.Phase;
                DutyCycle = (ushort)settings.PwmDutyCycle;
                PwmRate = settings.PwmRateHz;
                AdcDelayUs = settings.AdcDelayUs;
                MainViewModel.DebugPanel.PwrInDb = settings.PwrInDb;

                //// Read the DAC's too
                if (MainViewModel.DebugPanel != null)
                {
                    System.Threading.Thread.Sleep(250); // not too fast
                    MainViewModel.DebugPanel.CmdRead.Execute(null);
                }

                // fill-in serial numbers for S4
                if (MainViewModel.ICmd.HwType == InstrumentInfo.InstrumentType.S4)
                    MainViewModel.CalPanel.CmdReadSNs.Execute(null);
            }
        }
        // Backgroud thread...
        RfSettings ReadInitialSettings()
        {
            RfSettings settings = new RfSettings();
            try
            {
                System.Threading.Thread.Sleep(200); // wait a bit
                int status = MainViewModel.ICmd.GetState(ref settings);
                if(status != 0)
                    settings.ErrorMessage = string.Format(" Read initial values failed:{0}", MainViewModel.IErr.ErrorDescription(status));
            }
            catch (Exception ex)
            {
                settings.ErrorMessage = string.Format("Read initial values exception:{0}", ex.Message);
            }
            return settings;
        }
    }
}
