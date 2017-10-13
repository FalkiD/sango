using System;
using RFenergyUI.ViewModels;
using M2TestModule;
using System.Threading.Tasks;
using System.Collections.Generic;

namespace RFenergyUI.Models
{
    /// <summary>
    /// Business logic for Test ViewModel
    /// Access the hardware through driver assemblies that
    /// implement the required interfaces.
    /// </summary>
    public class TestModel
    {
        const double VOLTS_PER_LSB = 3.3 / 4095.0;

        const int EEPROM_SIZE = 3072;   // M2 LPC11U68
        const int BLOCK_SIZE = 16; 

        TestViewModel _m2vm;
        bool _monitorBusy;
        static object _monitorLock = new object();

        public TestModel(TestViewModel vm)
        {
            Initialized = false;
            _monitorBusy = false;
            _m2vm = vm;
            //_results = new MonitorPa[HW_CHANNELS];

            //LoopDelayMs = 750;
            //LoopReadings = false;

            //CmdRead = ReactiveCommand.CreateAsyncObservable(x => CmdReadDacsRun());
            //CmdRead.Subscribe(result => MainViewModel.MsgAppendLine(result));

            //CmdFrequency = ReactiveCommand.CreateAsyncObservable(x => CmdFrqRun());
            //CmdFrequency.Subscribe(result => MainViewModel.MsgAppendLine(result));
            //CmdFrqArrow = ReactiveCommand.CreateAsyncObservable(x => CmdFrqArrowRun(x));
            //CmdFrqArrow.Subscribe(result => MainViewModel.MsgAppendLine(result));

            //CmdPower = ReactiveCommand.CreateAsyncObservable(x => CmdPwrRun());
            //CmdPower.Subscribe(result => MainViewModel.MsgAppendLine(result));
            //CmdPwrArrow = ReactiveCommand.CreateAsyncObservable(x => CmdPwrArrowRun(x));
            //CmdPwrArrow.Subscribe(result => MainViewModel.MsgAppendLine(result));

            //CmdPhase = ReactiveCommand.CreateAsyncObservable(x => CmdPhsRun());
            //CmdPhase.Subscribe(result => MainViewModel.MsgAppendLine(result));
            //CmdPhsArrow = ReactiveCommand.CreateAsyncObservable(x => CmdPhsArrowRun(x));
            //CmdPhsArrow.Subscribe(result => MainViewModel.MsgAppendLine(result));

            //CmdPwm = ReactiveCommand.CreateAsyncObservable(x => CmdPwmRun());
            //CmdPwm.Subscribe(result => MainViewModel.MsgAppendLine(result));
            //CmdPwmDutyArrow = ReactiveCommand.CreateAsyncObservable(x => CmdPwmDutyArrowRun(x));
            //CmdPwmDutyArrow.Subscribe(result => MainViewModel.MsgAppendLine(result));
            //CmdPwmTArrow = ReactiveCommand.CreateAsyncObservable(x => CmdPwmTArrowRun(x));
            //CmdPwmTArrow.Subscribe(result => MainViewModel.MsgAppendLine(result));

            //// Sweep buttons
            //CmdFrqSweep = ReactiveCommand.CreateAsyncObservable(x => CmdFrqSweepRun());
            //CmdFrqSweep.Subscribe(result => MainViewModel.MsgAppendLine(result));
            //FrqSweepRunning = false;
            //FrqSweepBtnTxt = STR_START_SWEEP;
            //MsPerStep = 750;

            //CmdPwrSweep = ReactiveCommand.CreateAsyncObservable(x => CmdPwrSweepRun());
            //CmdPwrSweep.Subscribe(result => MainViewModel.MsgAppendLine(result));
            //PwrSweepRunning = false;
            //PwrSweepBtnTxt = STR_START_SWEEP;

            //// Measure buttons
            //CmdCombinerMeasure = ReactiveCommand.CreateAsyncObservable(x => CmdCombinerRun());
            //CmdCombinerMeasure.Subscribe(result => MainViewModel.MsgAppendLine(result));
            //CmdZMonMeasure = ReactiveCommand.CreateAsyncObservable(x => CmdZMonMeasRun());
            //CmdZMonMeasure.Subscribe(result => MainViewModel.MsgAppendLine(result));

        }

        public int LastProgrammedValues()
        {
            EEPROM = new byte[EEPROM_SIZE];
            string result = "";
            try
            {
                if (MainViewModel.IDbg != null)
                {
                    byte[] data = new byte[BLOCK_SIZE];
                    int status = 0, address = 0;
                    int block;
                    for (block = 0; block < EEPROM_SIZE/BLOCK_SIZE; 
                        ++block, address += BLOCK_SIZE)
                    {
                        status = MainViewModel.IDbg.ReadEeprom(address, ref data);
                        if (status == 0)
                        {
                            if (data.Length >= BLOCK_SIZE)
                            {
                                Array.Copy(data, 0, EEPROM, address, BLOCK_SIZE);
                            }
                            else result = string.Format(" LastProgrammedValues failed to read, block:{0}", block);
                        }
                        else result = string.Format(" LastProgrammedValues failed to read:{0}", MainViewModel.IErr.ErrorDescription(status));
                    }
                }
                else result = "IDbg interface is null, can't execute anything";
                Initialized = true;
            }
            catch (Exception ex)
            {
                result = string.Format("LastProgrammedValues Exception:{0}", ex.Message);
            }
            return 0;
        }

        // properties

        public bool Initialized { get; set; }
        byte[] EEPROM { get; set; }

        //bool _phaseVisible;
        //public bool PhaseVisible
        //{
        //    get { return _phaseVisible; }
        //    set { this.RaiseAndSetIfChanged(ref _phaseVisible, value); }
        //}

        //ObservableCollection<ChannelViewModel> _channelVms;
        //public ObservableCollection<ChannelViewModel> ChannelVms
        //{
        //    get { return _channelVms; }
        //    set { this.RaiseAndSetIfChanged(ref _channelVms, value); }
        //}

        //ObservableCollection<PaViewModel> _paVms;
        //public ObservableCollection<PaViewModel> PaVms
        //{
        //    get { return _paVms; }
        //    set { this.RaiseAndSetIfChanged(ref _paVms, value); }
        //}

        //IQDacViewModel _iqDacIVm;
        //public IQDacViewModel IqDacIVm
        //{
        //    get { return _iqDacIVm; }
        //    set { this.RaiseAndSetIfChanged(ref _iqDacIVm, value); }
        //}

        //IQDacViewModel _iqDacQVm;
        //public IQDacViewModel IqDacQVm
        //{
        //    get { return _iqDacQVm; }
        //    set { this.RaiseAndSetIfChanged(ref _iqDacQVm, value); }
        //}

        //double _frequency;
        //public double Frequency
        //{
        //    get { return _frequency; }
        //    set { this.RaiseAndSetIfChanged(ref _frequency, value); }
        //}
        //double _freqTop;
        //public double FreqTop
        //{
        //    get { return _freqTop; }
        //    set { this.RaiseAndSetIfChanged(ref _freqTop, value); }
        //}
        //double _freqStepSize;
        //public double FreqStepSize
        //{
        //    get { return _freqStepSize; }
        //    set { this.RaiseAndSetIfChanged(ref _freqStepSize, value); }
        //}
        //double _msPerStep;
        //public double MsPerStep
        //{
        //    get { return _msPerStep; }
        //    set { this.RaiseAndSetIfChanged(ref _msPerStep, value); }
        //}

        //double _power;
        //public double Power
        //{
        //    get { return _power; }
        //    set { this.RaiseAndSetIfChanged(ref _power, value); }
        //}
        //double _powerTop;
        //public double PowerTop
        //{
        //    get { return _powerTop; }
        //    set { this.RaiseAndSetIfChanged(ref _powerTop, value); }
        //}
        //double _powerStepSize;
        //public double PowerStepSize
        //{
        //    get { return _powerStepSize; }
        //    set { this.RaiseAndSetIfChanged(ref _powerStepSize, value); }
        //}

        //double _phase;
        //public double Phase
        //{
        //    get { return _phase; }
        //    set { this.RaiseAndSetIfChanged(ref _phase, value); }
        //}

        //double _combinerPower;
        //public double CombinerPower
        //{
        //    get { return _combinerPower; }
        //    set { this.RaiseAndSetIfChanged(ref _combinerPower, value); }
        //}

        //double _forwardPower;
        //public double ForwardPower
        //{
        //    get { return _forwardPower; }
        //    set { this.RaiseAndSetIfChanged(ref _forwardPower, value); }
        //}

        //double _reflectedPower;
        //public double ReflectedPower
        //{
        //    get { return _reflectedPower; }
        //    set { this.RaiseAndSetIfChanged(ref _reflectedPower, value); }
        //}

        //ushort _dutycycle;
        //public ushort DutyCycle
        //{
        //    get { return _dutycycle; }
        //    set { this.RaiseAndSetIfChanged(ref _dutycycle, value); }
        //}

        //int _period;
        //public int Period
        //{
        //    get { return _period; }
        //    set { this.RaiseAndSetIfChanged(ref _period, value); }
        //}

        //bool _externalPwm;
        //public bool ExternalPwm
        //{
        //    get { return _externalPwm; }
        //    set { this.RaiseAndSetIfChanged(ref _externalPwm, value); }
        //}

        //bool _pwmON;
        //public bool PwmON
        //{
        //    get { return _pwmON; }
        //    set { this.RaiseAndSetIfChanged(ref _pwmON, value); }
        //}

        //bool _loopReadings;
        //public bool LoopReadings
        //{
        //    get { return _loopReadings; }
        //    set
        //    {
        //        if (_m2view.TestTimer != null)
        //        {
        //            if (value)
        //                _m2view.TestTimer.Start();
        //            else
        //                _m2view.TestTimer.Stop();
        //        }
        //        this.RaiseAndSetIfChanged(ref _loopReadings, value);
        //    }
        //}

        //int _loopDelayMs;
        //public int LoopDelayMs
        //{
        //    get { return _loopDelayMs; }
        //    set
        //    {
        //        if (_m2view.TestTimer != null)
        //        {
        //            bool reset = false;
        //            if (LoopReadings)
        //            {
        //                reset = true;
        //                _m2view.TestTimer.Stop();
        //            }
        //            _m2view.TestTimer.Interval = new TimeSpan(0, 0, 0, 0, value);
        //            if (reset)
        //                _m2view.TestTimer.Start();
        //        }
        //        this.RaiseAndSetIfChanged(ref _loopDelayMs, value);
        //    }
        //}

        //// commands
        //IObservable<string> CmdReadDacsRun()
        //{
        //    string result = "";
        //    int channel = 1;
        //    try
        //    {
        //        if (MainViewModel.IDbg != null)
        //        {
        //            byte[] data = new byte[24];
        //            int status = 0;
        //            int channelsSelected = 0;
        //            for (channel = 1; channel <= HW_CHANNELS; ++channel)
        //            {
        //                if (ChannelVms[channel - 1].IsSelected)
        //                {
        //                    ++channelsSelected;
        //                    status = MainViewModel.IDbg.ReadI2C(channel, 0x60, null, data);
        //                    if (status == 0)
        //                    {
        //                        if (data.Length == 24)
        //                        {
        //                            int value = (data[2] | ((data[1] & 0xf) << 8)) & 0xfff;
        //                            ChannelVms[channel - 1].PhaseDacVm.DacValue = value * VOLTS_PER_LSB;
        //                            ChannelVms[channel - 1].PhaseDacVm.DacBits = (ushort)value;

        //                            value = (data[8] | ((data[7] & 0xf) << 8)) & 0xfff;
        //                            ChannelVms[channel - 1].GainDacVm.DacValue = value * VOLTS_PER_LSB;
        //                            ChannelVms[channel - 1].GainDacVm.DacBits = (ushort)value;

        //                            value = (data[14] | ((data[13] & 0xf) << 8)) & 0xfff;
        //                            ChannelVms[channel - 1].Bias1DacVm.DacValue = value * VOLTS_PER_LSB;
        //                            ChannelVms[channel - 1].Bias1DacVm.DacBits = (ushort)value;

        //                            value = (data[20] | ((data[19] & 0xf) << 8)) & 0xfff;
        //                            ChannelVms[channel - 1].Bias2DacVm.DacValue = value * VOLTS_PER_LSB;
        //                            ChannelVms[channel - 1].Bias2DacVm.DacBits = (ushort)value;
        //                            result = string.Format(" Channel {0} ReadDAC Ok", channel);
        //                        }
        //                        else result = string.Format(" Channel {0} ReadDAC failed to read 0x18 bytes, read:{1}", channel, data.Length);
        //                    }
        //                    else result = string.Format(" Channel {0} Dac read failed:{1}", channel, MainViewModel.IErr.ErrorDescription(status));
        //                }
        //            }
        //            if (channelsSelected == 0)
        //                result = "Error, no channels selected";
        //        }
        //        else result = "IDbg interface is null, can't execute anything";
        //    }
        //    catch (Exception ex)
        //    {
        //        result = string.Format("CmdRead{0} Exception:{1}", channel, ex.Message);
        //    }
        //    return Observable.Return(result);
        //}

        //IObservable<string> CmdFrqRun()
        //{
        //    string result = "";
        //    try
        //    {
        //        if (MainViewModel.ICmd != null)
        //        {
        //            int frq = (int)(Frequency * 65536.0);     // Q15.16 format
        //            byte[] rsp = new byte[512];
        //            rsp[0] = 0xFF;  // just flag error until fixup MMC returned status
        //            int status = MainViewModel.ICmd.SetFrequency(Frequency);
        //            // TBD fix this up...
        //            if (status == 0)
        //            {
        //                if (MainViewModel.SelectedSystemName.StartsWith("MMC"))
        //                {
        //                    if (rsp[0] == 0x01)
        //                        result = " MMC Frequency Opcode Successful.";
        //                    else
        //                        result = string.Format(" MMC Frequency Opcode failed:0x{0}", rsp[0]); // MainViewModel.IErr.ErrorDescription(status));

        //                    List<string> results = new List<string>();
        //                    string more = string.Format("  {0:x02} {1:x02} {2:x02} {3:x02} {4:x02} {5:x02} {6:x02} {7:x02}",
        //                                            rsp[0], rsp[1], rsp[2], rsp[3], rsp[4], rsp[5], rsp[6], rsp[7]);

        //                    result += (", " + more);
        //                    //results.Add(string.Format("  {0:x02} {1:x02} {2:x02} {3:x02} {4:x02} {5:x02} {6:x02} {7:x02}",
        //                    //                        rsp[8], rsp[9], rsp[10], rsp[11], rsp[12], rsp[13], rsp[14], rsp[15]));

        //                }
        //                else result = " Set frequency Ok";
        //            }
        //            else result = string.Format(" Set Frequency failed:{0}", MainViewModel.IErr.ErrorDescription(status));
        //        }
        //        else result = "ICmd interface is null, can't execute anything";
        //    }
        //    catch (Exception ex)
        //    {
        //        result = string.Format("Set Frequency exception:{0}", ex.Message);
        //    }
        //    return Observable.Return(result);
        //}

        //IObservable<string> CmdPwrRun()
        //{
        //    string result = "";
        //    try
        //    {
        //        if (MainViewModel.ICmd != null)
        //        {
        //            int status = MainViewModel.ICmd.SetPower(Power);
        //            if (status == 0)
        //                result = " Set power Ok";
        //            else result = string.Format(" Set power failed:{0}", MainViewModel.IErr.ErrorDescription(status));
        //        }
        //        else result = "ICmd interface is null, can't execute anything";
        //    }
        //    catch (Exception ex)
        //    {
        //        result = string.Format("Set Power exception:{0}", ex.Message);
        //    }
        //    return Observable.Return(result);
        //}
        //IObservable<string> CmdPhsRun()
        //{
        //    string result = "";
        //    try
        //    {
        //        if (MainViewModel.ICmd != null)
        //        {
        //            int pwr = (int)(Phase * 256.0);     // Q7.8 format
        //            byte[] cmd = new byte[3];
        //            cmd[0] = M2Cmd.PHASE;
        //            cmd[1] = (byte)(pwr & 0xff);
        //            cmd[2] = (byte)((pwr >> 8) & 0xff);
        //            byte[] rsp = null;
        //            int status = MainViewModel.ICmd.RunCmd(cmd, ref rsp);
        //            if (status == 0)
        //                result = " Set phase Ok";
        //            else result = string.Format(" Set phase failed:{0}", MainViewModel.IErr.ErrorDescription(status));
        //        }
        //        else result = "ICmd interface is null, can't execute anything";
        //    }
        //    catch (Exception ex)
        //    {
        //        result = string.Format("Set Phase exception:{0}", ex.Message);
        //    }
        //    return Observable.Return(result);
        //}
        //IObservable<string> CmdPhsArrowRun(object arrow)
        //{
        //    return Observable.Return("");
        //}

        //IObservable<string> CmdPwmRun()
        //{
        //    string result = "";
        //    try
        //    {
        //        if (MainViewModel.ICmd != null)
        //        {
        //            byte[] cmd = new byte[5];
        //            cmd[0] = M2Cmd.PWM;
        //            if (ExternalPwm)
        //            {
        //                cmd[1] = 0x02;
        //            }
        //            else
        //            {
        //                if (DutyCycle >= 100)
        //                {
        //                    if (DutyCycle > 100)
        //                        DutyCycle = 100;
        //                    if (DutyCycle == 100)
        //                        cmd[1] = 0x01;
        //                    else cmd[1] = 0;
        //                }
        //                cmd[2] = (byte)DutyCycle;
        //                if (Period > 1000000)
        //                    Period = 1000000;
        //                else if (Period < 1000)
        //                    Period = 1000;
        //                int khz = Period / 1000;
        //                cmd[3] = (byte)(khz & 0xff);
        //                cmd[4] = (byte)((khz >> 8) & 3);
        //            }
        //            byte[] rsp = null;
        //            int status = MainViewModel.ICmd.RunCmd(cmd, ref rsp);
        //            if (status == 0)
        //                result = " Set PWM Ok";
        //            else result = string.Format(" Set PWM failed:{0}", MainViewModel.IErr.ErrorDescription(status));
        //        }
        //        else result = "ICmd interface is null, can't execute anything";
        //    }
        //    catch (Exception ex)
        //    {
        //        result = string.Format("Set PWM exception:{0}", ex.Message);
        //    }
        //    return Observable.Return(result);
        //}

        //// Sweep button properties, run funcs
        //bool _frqSweepRunning;
        //public bool FrqSweepRunning
        //{
        //    get { return _frqSweepRunning; }
        //    set { this.RaiseAndSetIfChanged(ref _frqSweepRunning, value); }
        //}
        //IObservable<string> CmdFrqSweepRun()
        //{
        //    string result = "";
        //    try
        //    {
        //        if (MainViewModel.ICmd != null)
        //        {
        //            if (FrqSweepRunning)
        //            {
        //                FrqSweepBtnTxt = STR_START_SWEEP;
        //                FrqSweepRunning = false;
        //                result = " Frequency sweep stopped";
        //            }
        //            else
        //            {
        //                FrqSweepBtnTxt = STR_STOP_SWEEP;
        //                FrqSweepRunning = true;
        //                BackgroundWorker frqworker = new BackgroundWorker();
        //                frqworker.WorkerReportsProgress = true;
        //                frqworker.DoWork += freq_DoWork;
        //                frqworker.ProgressChanged += freq_ProgressChanged;
        //                frqworker.RunWorkerCompleted += freq_RunWorkerCompleted;
        //                frqworker.RunWorkerAsync(1000000);
        //            }
        //            result = string.Format(" begin freq, start:{0:f1}, end:{1:f1}, step:{2:f1}", Frequency, FreqTop, FreqStepSize);
        //        }
        //        else result = "ICmd interface is null, can't execute anything";
        //    }
        //    catch (Exception ex)
        //    {
        //        result = string.Format("Start frequency sweep exception:{0}", ex.Message);
        //    }
        //    return Observable.Return(result);
        //}

        //void freq_DoWork(object sender, DoWorkEventArgs e)
        //{
        //    int steps = (int)((FreqTop - Frequency + 0.5) / FreqStepSize);
        //    double frq;
        //    for (int j = 0; j < steps; ++j)
        //    {
        //        frq = Frequency + (j * FreqStepSize);
        //        int status = MainViewModel.ICmd.SetFrequency(frq);
        //        string msg;
        //        if (status != 0)
        //        {
        //            msg = string.Format("Set frequency {0} Hz failed, status:{1}, exit sweep", frq, status);
        //            FrqSweepRunning = false;
        //        }
        //        else
        //        {
        //            msg = string.Format("Set frequency {0} Hz, step {1} of {2} Ok", frq, j + 1, steps);
        //        }
        //        (sender as BackgroundWorker).ReportProgress(0, msg);
        //        if (FrqSweepRunning == false)
        //            break;
        //        if (MsPerStep > 0)
        //            System.Threading.Thread.Sleep((int)MsPerStep);
        //    }
        //    e.Result = 0;
        //}

        //void freq_ProgressChanged(object sender, ProgressChangedEventArgs e)
        //{
        //    if (e.UserState != null)
        //        MainViewModel.MsgAppendLine((string)e.UserState);
        //}

        //void freq_RunWorkerCompleted(object sender, RunWorkerCompletedEventArgs e)
        //{
        //    MainViewModel.MsgAppendLine("Frequency sweep done");
        //}
        //// End of frequency sweep


        //bool _pwrSweepRunning;
        //public bool PwrSweepRunning
        //{
        //    get { return _pwrSweepRunning; }
        //    set { this.RaiseAndSetIfChanged(ref _pwrSweepRunning, value); }
        //}
        //IObservable<string> CmdPwrSweepRun()
        //{
        //    string result = "";
        //    try
        //    {
        //        if (MainViewModel.ICmd != null)
        //        {
        //            int status = 0;
        //            if (PwrSweepRunning)
        //            {
        //                PwrSweepBtnTxt = STR_START_SWEEP;
        //                PwrSweepRunning = false;
        //                result = " Power sweep stopped";
        //            }
        //            else
        //            {
        //                PwrSweepBtnTxt = STR_STOP_SWEEP;
        //                PwrSweepRunning = true;
        //                BackgroundWorker worker = new BackgroundWorker();
        //                worker.WorkerReportsProgress = true;
        //                worker.DoWork += pwr_DoWork;
        //                worker.ProgressChanged += pwr_ProgressChanged;
        //                worker.RunWorkerCompleted += pwr_RunWorkerCompleted;
        //                worker.RunWorkerAsync(1000000);
        //                result = string.Format(" begin power sweep, start:{0:f1}, end:{1:f1}, stepsize:{2:f1}", Power, PowerTop, PowerStepSize);
        //            }
        //        }
        //        else result = "ICmd interface is null, can't execute anything";
        //    }
        //    catch (Exception ex)
        //    {
        //        result = string.Format("Start power sweep exception:{0}", ex.Message);
        //    }
        //    return Observable.Return(result);
        //}
        //void pwr_DoWork(object sender, DoWorkEventArgs e)
        //{
        //    int steps = (int)((PowerTop - Power + 0.05) / PowerStepSize);
        //    double dbm;
        //    for (int j = 0; j < steps; ++j)
        //    {
        //        dbm = Power + (j * PowerStepSize);
        //        int status = MainViewModel.ICmd.SetPower(dbm);
        //        string msg;
        //        if (status != 0)
        //        {
        //            msg = string.Format("Set power {0:f1} dBm failed, status:{1}, exit sweep", dbm, status);
        //            PwrSweepRunning = false;
        //        }
        //        else
        //        {
        //            msg = string.Format("Set power {0:f1} dBm, step {1} of {2} Ok", dbm, j + 1, steps);
        //        }
        //        (sender as BackgroundWorker).ReportProgress(0, msg);
        //        if (PwrSweepRunning == false)
        //            break;
        //        if (MsPerStep > 0)
        //            System.Threading.Thread.Sleep((int)MsPerStep);
        //    }
        //    e.Result = 0;
        //}

        //void pwr_ProgressChanged(object sender, ProgressChangedEventArgs e)
        //{
        //    if (e.UserState != null)
        //        MainViewModel.MsgAppendLine((string)e.UserState);
        //}

        //void pwr_RunWorkerCompleted(object sender, RunWorkerCompletedEventArgs e)
        //{
        //    MainViewModel.MsgAppendLine("Power sweep done");
        //}
        //// End of power sweep



        //IObservable<string> CmdCombinerRun()
        //{
        //    string result = "";
        //    try
        //    {
        //        if (MainViewModel.ICmd != null)
        //        {
        //            //int status = 0;
        //            //if (PwrSweepRunning)
        //            //{
        //            //    PwrSweepBtnTxt = STR_START_SWEEP;
        //            //    PwrSweepRunning = false;
        //            //    if (status == 0)
        //            //        result = " Power sweep stopped";
        //            //    else result = string.Format(" Stop power sweep failed:{0}", MainViewModel.IErr.ErrorDescription(status));
        //            //}
        //        }
        //        else result = "ICmd interface is null, can't execute anything";
        //    }
        //    catch (Exception ex)
        //    {
        //        result = string.Format("Start power sweep exception:{0}", ex.Message);
        //    }
        //    return Observable.Return(result);
        //}

        //IObservable<string> CmdZMonMeasRun()
        //{
        //    string result = "";
        //    try
        //    {
        //        if (MainViewModel.ICmd != null)
        //        {
        //            //int status = 0;
        //            //if (PwrSweepRunning)
        //            //{
        //            //    PwrSweepBtnTxt = STR_START_SWEEP;
        //            //    PwrSweepRunning = false;
        //            //    if (status == 0)
        //            //        result = " Power sweep stopped";
        //            //    else result = string.Format(" Stop power sweep failed:{0}", MainViewModel.IErr.ErrorDescription(status));
        //            //}
        //        }
        //        else result = "ICmd interface is null, can't execute anything";
        //    }
        //    catch (Exception ex)
        //    {
        //        result = string.Format("Start power sweep exception:{0}", ex.Message);
        //    }
        //    return Observable.Return(result);
        //}



        //// Timer from UI thread to update readings
        //public void TimerTick()
        //{
        //    if (_monitorBusy)
        //        return;

        //    lock (_monitorLock)
        //    {
        //        _monitorBusy = true;
        //        DoReadings();
        //        _monitorBusy = false;
        //    }
        //}

        //struct MonitorPa
        //{
        //    public double Voltage;
        //    public double Current;
        //    public double Temperature;
        //    public string ErrorMessage;
        //}
        //MonitorPa[] _results;
        //async void DoReadings()
        //{
        //    MonitorPa results = await Task.Run(() => ReadData());
        //    if (results.ErrorMessage.Length > 0)
        //        MainViewModel.MsgAppendLine(results.ErrorMessage);
        //    else
        //    {
        //        // back on UI thread, update ViewModels with _results
        //        for (int channel = 1; channel <= HW_CHANNELS; ++channel)
        //        {
        //            if (ChannelVms[channel - 1].IsSelected)
        //            {
        //                ChannelVms[channel - 1].PaVm.Current = _results[channel - 1].Current;
        //                ChannelVms[channel - 1].PaVm.Voltage = _results[channel - 1].Voltage;
        //                ChannelVms[channel - 1].PaVm.Temperature = _results[channel - 1].Temperature;
        //            }
        //        }
        //    }
        //}

        //MonitorPa ReadData()
        //{
        //    MonitorPa results = new MonitorPa();
        //    results.ErrorMessage = "";
        //    try
        //    {
        //        if (MainViewModel.ICmd != null)
        //        {
        //            int channel = -1;
        //            byte[] cmd = new byte[1];
        //            cmd[0] = M2Cmd.RF_STATUS;
        //            byte[] data = null;
        //            int status = MainViewModel.ICmd.RunCmd(cmd, ref data);
        //            if (status == 0)
        //            {
        //                if (data != null)
        //                {
        //                    for (channel = 1; channel <= HW_CHANNELS; ++channel)
        //                    {
        //                        if (ChannelVms[channel - 1].IsSelected)
        //                        {
        //                            int offset = 1 + 6 * (channel - 1);
        //                            int value = (data[offset + 1] << 8) | data[offset];
        //                            if ((value & 0x8000) != 0)
        //                                unchecked { value |= (int)0xffff0000; }
        //                            results.Temperature = value / 256.0;

        //                            value = ((data[offset + 3] << 8) | data[offset + 2]);
        //                            double tmp = (double)value / 256.0;
        //                            results.Voltage = tmp * 403.0 / 20.0;

        //                            value = (data[offset + 5] << 8) | data[offset + 4];
        //                            results.Current = value / 256.0;
        //                            _results[channel - 1] = results;
        //                        }
        //                    }
        //                }
        //                else results.ErrorMessage = " RF_STATUS returned no data, is M2 online?";
        //            }
        //            else results.ErrorMessage = string.Format(" RF_STATUS failed:{1}", MainViewModel.IErr.ErrorDescription(status));
        //        }
        //        else results.ErrorMessage = "ICmd interface is null, can't read anything";
        //    }
        //    catch (Exception ex)
        //    {
        //        results.ErrorMessage = string.Format("Read ADC's exception:{0}", ex.Message);
        //    }
        //    return results;
        //}
    }
}
