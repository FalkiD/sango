using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Reactive.Linq;
using System.Threading;
using ReactiveUI;
using RFenergyUI.Views;
using Interfaces;

namespace RFenergyUI.ViewModels
{
    public class RfeDebugViewModel : ReactiveObject
    {
        RfeDebugView _rfedebugview;

        public RfeDebugViewModel(RfeDebugView view)
        {
            _rfedebugview = view;

            EepromFilename = "EEPROMdump.bin";
            TemperatureFilename = "Temperature.csv";
            
            CmdExecute = ReactiveCommand.CreateAsyncObservable(x => CmdExecuteRun());
            CmdExecute.IsExecuting.ToProperty(this, x => x.IsExecuting, out _isExecuting);
            CmdExecute.Subscribe(result => CmdDone(result));
            CmdExecute.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdGetTag = ReactiveCommand.CreateAsyncObservable(x => CmdGetTagRun());
            CmdGetTag.IsExecuting.ToProperty(this, x => x.IsExecuting, out _isExecuting);
            CmdGetTag.Subscribe(result => CmdGetTagDone(result));
            CmdGetTag.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdSetTag = ReactiveCommand.CreateAsyncObservable(x => CmdSetTagRun());
            CmdSetTag.IsExecuting.ToProperty(this, x => x.IsExecuting, out _isExecuting);
            CmdSetTag.Subscribe(result => CmdDone(result));
            CmdSetTag.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdReadEEPROM = ReactiveCommand.CreateAsyncObservable(x => CmdReadEEPROMRun());
            CmdReadEEPROM.IsExecuting.ToProperty(this, x => x.IsExecuting, out _isExecuting);
            CmdReadEEPROM.Subscribe(result => CmdDone(result));
            CmdReadEEPROM.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdWriteEEPROM = ReactiveCommand.CreateAsyncObservable(x => CmdWriteEEPROMRun());
            CmdWriteEEPROM.IsExecuting.ToProperty(this, x => x.IsExecuting, out _isExecuting);
            CmdWriteEEPROM.Subscribe(result => CmdDone(result));
            CmdWriteEEPROM.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdEEPROMtoFile = ReactiveCommand.CreateAsyncObservable(x => CmdEEPROMtoFileRun());
            CmdEEPROMtoFile.IsExecuting.ToProperty(this, x => x.IsExecuting, out _isExecuting);
            CmdEEPROMtoFile.Subscribe(result => CmdDone(result));
            CmdEEPROMtoFile.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdPwrCalTags = ReactiveCommand.CreateAsyncObservable(x => CmdPwrCalTagsRun());
            CmdPwrCalTags.IsExecuting.ToProperty(this, x => x.IsExecuting, out _isExecuting);
            CmdPwrCalTags.Subscribe(result => CmdDone(result));
            CmdPwrCalTags.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdFileToEEPROM = ReactiveCommand.CreateAsyncObservable(x => CmdFileToEEPROMRun());
            CmdFileToEEPROM.IsExecuting.ToProperty(this, x => x.IsExecuting, out _isExecuting);
            CmdFileToEEPROM.Subscribe(result => CmdDone(result));
            CmdFileToEEPROM.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdReadI2C = ReactiveCommand.CreateAsyncObservable(x => CmdReadI2CRun());
            CmdReadI2C.IsExecuting.ToProperty(this, x => x.IsExecuting, out _isExecuting);
            CmdReadI2C.Subscribe(result => CmdDone(result));
            CmdReadI2C.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdWriteI2C = ReactiveCommand.CreateAsyncObservable(x => CmdWriteI2CRun());
            CmdWriteI2C.IsExecuting.ToProperty(this, x => x.IsExecuting, out _isExecuting);
            CmdWriteI2C.Subscribe(result => CmdDone(result));
            CmdWriteI2C.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdWrRdSPI = ReactiveCommand.CreateAsyncObservable(x => CmdWrRdSPIRun());
            CmdWrRdSPI.IsExecuting.ToProperty(this, x => x.IsExecuting, out _isExecuting);
            CmdWrRdSPI.Subscribe(result => CmdDone(result));
            CmdWrRdSPI.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdRead = ReactiveCommand.CreateAsyncObservable(x => CmdReadDacsRun());
            CmdRead.IsExecuting.ToProperty(this, x => x.IsExecuting, out _isExecuting);
            CmdRead.Subscribe(result => CmdDone(result));
            CmdRead.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdPwrInDb = ReactiveCommand.CreateAsyncObservable(x => CmdPwrInDbRun(x));
            CmdPwrInDb.IsExecuting.ToProperty(this, x => x.IsExecuting, out _isExecuting);
            CmdPwrInDb.Subscribe(result => CmdDone(result));
            CmdPwrInDb.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdModeSwitch = ReactiveCommand.CreateAsyncObservable(x => CmdModeRun());
            CmdModeSwitch.IsExecuting.ToProperty(this, x => x.IsExecuting, out _isExecuting);
            CmdModeSwitch.Subscribe(result => CmdDone(result));
            CmdModeSwitch.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdWritePwrCalTags = ReactiveCommand.CreateAsyncObservable(x => CmdWritePwrCalTagsRun());
            CmdWritePwrCalTags.IsExecuting.ToProperty(this, x => x.IsExecuting, out _isExecuting);
            CmdWritePwrCalTags.Subscribe(result => CmdDone(result));
            CmdWritePwrCalTags.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            CmdTemperatureData = ReactiveCommand.CreateAsyncObservable(x => CmdTemperatureDataRun());
            CmdTemperatureData.IsExecuting.ToProperty(this, x => x.IsTemperature, out _isTemperature);
            CmdExecute.Subscribe(result => CmdDone(result));
            CmdExecute.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));
            CmdStopTemperatureData = ReactiveCommand.CreateAsyncObservable(x => CmdStopTemperatureDataRun());
            CmdTemperatureData.IsExecuting.ToProperty(this, x => x.IsExecuting, out _isExecuting);
            CmdExecute.Subscribe(result => CmdDone(result));
            CmdExecute.ThrownExceptions.Subscribe(result => MainViewModel.MsgAppendLine(result.Message));

            ChannelVms = new ObservableCollection<ChannelViewModel>();

            MainViewModel.DebugPanel = this;
        }

        /// <summary>
        /// Startup items after window has been created
        /// </summary>
        public void SetupHardware()
        {
            for (int channel = 1; channel < MainViewModel.ICmd.PaChannels + 1; ++channel)
            {
                ChannelViewModel chvm = new ChannelViewModel
                {
                    Number = channel,
                    IsSelected = true,
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
                    }
                };
                if (MainViewModel.ICmd.HwType == InstrumentInfo.InstrumentType.S4)
                {
                    chvm.S4PaVm = new DacViewModel
                    {
                        Title = "S4 PA Bias",
                        WhichDac = Dac.eS4Pa,
                        Channel = 1,
                        ShowChannel = false
                    };
                }
                else chvm.S4PaVm = null;
                ChannelVms.Add(chvm);
            }

            // setup Visibility flags based on hardware type
            switch (MainViewModel.ICmd.HwType)
            {
                default:
                case InstrumentInfo.InstrumentType.M2:
                    M2Only = true;
                    S4Only = false;
                    X7Only = false;
                    break;
                case InstrumentInfo.InstrumentType.S4:
                    M2Only = false;
                    S4Only = true;
                    X7Only = false;
                    break;
                case InstrumentInfo.InstrumentType.X7:
                    M2Only = false;
                    S4Only = false;
                    X7Only = true;
                    break;
            }
        }

        // commands

        // Called when any command finishes
        void CmdDone(string result)
        {
            if (result.Length > 0)
                MainViewModel.MsgAppendLine(result);
        }

        void CmdDone(List<string> results)
        {
            if (results.Count > 0)
            {
                foreach(string str in results)
                    MainViewModel.MsgAppendLine(str);
            }
        }

        void CmdGetTagDone(List<string> results)
        {
            if (results.Count > 0)
            {
                int driverSn;
                if(Int32.TryParse(results[0], out driverSn))
                    MainViewModel.CalPanel.DriverSN = results[0];
                MainViewModel.MsgAppendLine(results[0]);
            }
        }

        public ReactiveCommand<string> CmdApply { get; protected set; }
        IObservable<string> CmdApplyRun()
        {
            // Apply button clicked

            //            AppendLine("LogWindow Test");
            //if (Interval > 1 && Interval < 120000)
            //{
            //    mainView.SetTimer(Interval);
            //}
            return Observable.Return("CmdApply() empty");
        }

        public ReactiveCommand<string> CmdModeSwitch { get; protected set; }
        IObservable<string> CmdModeRun()
        {
            // Observable.Start() starts the worker thread
            return Observable.Start(() =>
            {
                string rsp = "";
                try
                {
                    // d30=Mode4, d29=Mode3, d28=Mode2, d26=Mode1, d25=Mode0
                    int status = MainViewModel.ICmd.RunCmd("gr 6\n", ref rsp);
                    if(status == 0)
                    {
                        rsp = rsp.TrimEnd(new char[] { '>', '\n', '\r' });
                        const int MODE0 = 0x74000000;
                        const int MODE1 = 0x72000000;
                        const int MODE2 = 0x66000000;
                        const int MODE3 = 0x56000000;
                        const int MODE4 = 0x36000000;
                        int bits = Convert.ToInt32(rsp, 16) & 0x76000000;
                        switch(bits)
                        {
                            case MODE0:
                                rsp = "Mode0";
                                break;
                            case MODE1:
                                rsp = "Mode1";
                                break;
                            case MODE2:
                                rsp = "Mode2";
                                break;
                            case MODE3:
                                rsp = "Mode3";
                                break;
                            case MODE4:
                                rsp = "Mode4";
                                break;
                            default:
                                rsp = string.Format(" Mode switch error, read:0x{0:x}, expected d30,29,28,26,25 inverted pattern", bits);
                                break;
                        }
                    }
                }
                catch (Exception ex)
                {
                    rsp = string.Format("{0} CmdModeRun exception:{1}", MainViewModel.SelectedSystemName, ex.Message);
                }
                return rsp;
            });
        }

        public ReactiveCommand<List<string>> CmdRead { get; protected set; }
        IObservable<List<string>> CmdReadDacsRun()
        {
            return Observable.Start(() =>
            {
                List<string> results = new List<string>();
                int channel = 1;
                try
                {
                    if (MainViewModel.IDbg != null)
                    {
                        byte[] data = new byte[24];
                        int status = 0;
                        int channelsSelected = 0;
                        for (channel = 1; channel <= MainViewModel.ICmd.PaChannels; ++channel)
                        {
                            if (ChannelVms[channel - 1].IsSelected)
                            {
                                ++channelsSelected;
                                status = MainViewModel.IDbg.ReadI2C(channel, 0x60, null, data);
                                if (status == 0)
                                {
                                    if (data.Length == 24)
                                    {
                                        int value = (data[2] | ((data[1] & 0xf) << 8)) & 0xfff;
                                        ChannelVms[channel - 1].PhaseDacVm.DacValue = value * TestViewModel.VOLTS_PER_LSB;
                                        ChannelVms[channel - 1].PhaseDacVm.DacBits = (ushort)value;
                                        MainViewModel.TestPanel.ChannelVms[channel - 1].PhaseDacVm.DacValue = ChannelVms[channel - 1].PhaseDacVm.DacValue;
                                        MainViewModel.TestPanel.ChannelVms[channel - 1].PhaseDacVm.DacBits = (ushort)value;

                                        value = (data[8] | ((data[7] & 0xf) << 8)) & 0xfff;
                                        ChannelVms[channel - 1].GainDacVm.DacValue = value * TestViewModel.VOLTS_PER_LSB;
                                        ChannelVms[channel - 1].GainDacVm.DacBits = (ushort)value;
                                        MainViewModel.TestPanel.ChannelVms[channel - 1].GainDacVm.DacValue = ChannelVms[channel - 1].GainDacVm.DacValue;
                                        MainViewModel.TestPanel.ChannelVms[channel - 1].GainDacVm.DacBits = (ushort)value;

                                        value = (data[14] | ((data[13] & 0xf) << 8)) & 0xfff;
                                        ChannelVms[channel - 1].Bias1DacVm.DacValue = value * TestViewModel.VOLTS_PER_LSB;
                                        ChannelVms[channel - 1].Bias1DacVm.DacBits = (ushort)value;
                                        MainViewModel.TestPanel.ChannelVms[channel - 1].Bias1DacVm.DacValue = ChannelVms[channel - 1].Bias1DacVm.DacValue;
                                        MainViewModel.TestPanel.ChannelVms[channel - 1].Bias1DacVm.DacBits = (ushort)value;

                                        value = (data[20] | ((data[19] & 0xf) << 8)) & 0xfff;
                                        ChannelVms[channel - 1].Bias2DacVm.DacValue = value * TestViewModel.VOLTS_PER_LSB;
                                        ChannelVms[channel - 1].Bias2DacVm.DacBits = (ushort)value;
                                        MainViewModel.TestPanel.ChannelVms[channel - 1].Bias2DacVm.DacValue = ChannelVms[channel - 1].Bias2DacVm.DacValue;
                                        MainViewModel.TestPanel.ChannelVms[channel - 1].Bias2DacVm.DacBits = (ushort)value;
                                        results.Add(string.Format(" Channel {0} ReadDAC Ok", channel));
                                    }
                                    else results.Add(string.Format(" Channel {0} ReadDAC failed to read 0x18 bytes, read:{1}", channel, data.Length));
                                }
                                else results.Add(string.Format(" Channel {0} Dac read failed:{1}", channel, MainViewModel.IErr.ErrorDescription(status)));
                            }
                        }

                        // For S4 read PA bias DAC too
                        if (MainViewModel.ICmd.HwType == InstrumentInfo.InstrumentType.S4)
                        {
                            status = MainViewModel.IDbg.ReadI2C(channel, 0x61, null, data);
                            if (status == 0)
                            {
                                if (data.Length == 24)
                                {
                                    int value = (data[2] | ((data[1] & 0xf) << 8)) & 0xfff;
                                    ChannelVms[0].S4PaVm.DacValue = value * TestViewModel.VOLTS_PER_LSB;
                                    ChannelVms[0].S4PaVm.DacBits = (ushort)value;
                                    MainViewModel.TestPanel.ChannelVms[0].S4PaVm.DacValue = ChannelVms[0].S4PaVm.DacValue;
                                    MainViewModel.TestPanel.ChannelVms[0].S4PaVm.DacBits = (ushort)value;
                                }
                                else results.Add(string.Format(" Channel {0} Read PA Dac failed to read 0x18 bytes, read:{1}", channel, data.Length));
                            }
                            else results.Add(string.Format(" Channel {0} PA Dac read failed:{1}", channel, MainViewModel.IErr.ErrorDescription(status)));
                        }

                        if (channelsSelected == 0)
                            results.Add("Error, no channels selected");
                    }
                    else results.Add("IDbg interface is null, can't execute anything");
                }
                catch (Exception ex)
                {
                    results.Add(string.Format("CmdRead{0} Exception:{1}", channel, ex.Message));
                }
                return results;
            });
        }

        readonly ObservableAsPropertyHelper<bool> _isExecuting;
        public bool IsExecuting { get { return _isExecuting.Value; } }
        public ReactiveCommand<List<string>> CmdExecute { get; protected set; }
        IObservable<List<string>> CmdExecuteRun()
        {
            return Observable.Start(() =>
            {
                List<string> results = new List<string>();
                try
                {
                    if (MainViewModel.ICmd != null)
                    {
                        string response = "";
                        int status = MainViewModel.ICmd.RunCmd(CmdData, ref response);
                        if (status == 0)
                        {
                            results.AddRange(MainViewModel.ICmd.Results);
                        }
                        else results.Add(string.Format("RunCmd error:{0}", MainViewModel.IErr.ErrorDescription(status)));
                    }
                    else results.Add("ICommand interface is null, can't execute anything");
                }
                catch (Exception ex)
                {
                    results.Add(string.Format("RunCmd Exception:{0}", ex.Message));
                }
                return results;
            });
        }

        public ReactiveCommand<List<string>> CmdGetTag { get; protected set; }
        IObservable<List<string>> CmdGetTagRun()
        {
            return Observable.Start(() =>
            {
                List<string> results = new List<string>();
                try
                {
                    if (MainViewModel.IDbg != null)
                    {
                        string tag = "";
                        int status = MainViewModel.IDbg.GetTag(GetTag, ref tag);
                        if (status == 0)
                        {
                            tag = tag.TrimEnd(new char[] { '>', '\n', '\r' });
                            results.Add(tag);
                        }
                        else
                            results.Add(string.Format("Tag {0} not found or error", GetTag));
                    }
                    else 
                        results.Add("MainViewModel.IDbg interface is null, can't execute anything");
                }

                catch (Exception ex)
                {
                    results.Add(string.Format("Exception getting tag {0}:{1}", GetTag, ex.Message));
                }
                return results;
            });
        }

        public ReactiveCommand<string> CmdSetTag { get; protected set; }
        IObservable<string> CmdSetTagRun()
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    if (MainViewModel.IDbg != null)
                    {
                        int status = MainViewModel.IDbg.SetTag(SetTag, TagData);
                        if (status == 0)
                            result = string.Format("SetTag {0}={1} Ok", SetTag, TagData);
                        else
                            result = string.Format("SetTag {0}={1} failed", SetTag, TagData);
                    }
                    else
                        result = "MainViewModel.IDbg interface is null, can't execute anything";
                }

                catch (Exception ex)
                {
                    result = string.Format("Exception setting tag {0}={1}:{2}", SetTag, TagData, ex.Message);
                }
                return result;
            });
        }

        public ReactiveCommand<List<string>> CmdReadEEPROM { get; protected set; }
        IObservable<List<string>> CmdReadEEPROMRun()
        {
            return Observable.Start(() =>
            {
                List<string> results = new List<string>();
                try
                {
                    if (MainViewModel.IDbg != null)
                    {
                        // ReadEEPROM prop contains hex offset,bytes string
                        string[] args = ReadEEPROM.Split(new char[] { ' ', ',' });
                        if (ReadEEPROM == null || args.Length == 0)
                            throw new ApplicationException("ReadEEPROM args string format is hex: 'offset,bytes'");

                        int offset = Convert.ToInt16(args[0], 16);
                        int length = 16;
                        if (args.Length == 2)
                            length = Convert.ToInt16(args[1], 16);
                        const int BYTES_PER_READ = 16;  // due to HID report size being 32
                        byte[] data = new byte[BYTES_PER_READ];
                        int count = length / BYTES_PER_READ;
                        if (length % BYTES_PER_READ > 0)
                            ++count;
                        for (int k = 0; k < count; ++k)
                        {
                            int status = MainViewModel.IDbg.ReadEeprom(offset, ref data);
                            if (status == 0)
                            {
                                char[] asc = new char[data.Length];
                                for (int j = 0; j < data.Length; ++j)
                                {
                                    char tmp;
                                    unchecked { tmp = (char)data[j]; }
                                    if (char.IsControl(tmp))
                                        tmp = '.';
                                    asc[j] = tmp;
                                }
                                results.Add(string.Format(
                                    "  {16:x04}:{0:x02} {1:x02} {2:x02} {3:x02} {4:x02} {5:x02} {6:x02} {7:x02}  {8}{9}{10}{11}{12}{13}{14}{15}",
                                       data[0], data[1], data[2], data[3], data[4], data[5], data[6], data[7],
                                       asc[0], asc[1], asc[2], asc[3], asc[4], asc[5], asc[6], asc[7], offset));
                                results.Add(string.Format(
                                    "  {16:x04}:{0:x02} {1:x02} {2:x02} {3:x02} {4:x02} {5:x02} {6:x02} {7:x02}  {8}{9}{10}{11}{12}{13}{14}{15}",
                                        data[8], data[9], data[10], data[11], data[12], data[13], data[14], data[15],
                                        asc[8], asc[9], asc[10], asc[11], asc[12], asc[13], asc[14], asc[15], offset + (BYTES_PER_READ / 2)));
                                offset += BYTES_PER_READ;
                            }
                            else
                            {
                                results.Add(string.Format("Error reading EEPROM:{0}", MainViewModel.IErr.ErrorDescription(status)));
                                break;
                            }
                        }

                    }
                    else results.Add("MainViewModel.IDbg interface is null, can't execute anything");
                }
                catch (Exception ex)
                {
                    results.Add(string.Format("Exception getting tag {0}:{1}", GetTag, ex.Message));
                }
                return results;
            });
        }

        public ReactiveCommand<string> CmdWriteEEPROM { get; protected set; }
        IObservable<string> CmdWriteEEPROMRun()
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    if (MainViewModel.IDbg != null)
                    {
                        // ReadEEPROM prop contains hex offset,bytes string
                        string[] args = WriteEEPROM.Split(new char[] { ' ', ',' });
                        if (WriteEEPROM == null || args.Length < 3)
                            throw new ApplicationException("WriteEEPROM args format(hex), bytes 0,1 are offset LS,MS: 'AA,BB,D0,D1,D2,D3'");

                        int offset = Convert.ToInt16(args[0], 16);
                        offset |= (Convert.ToInt16(args[1], 16) << 8);
                        int length = args.Length - 2;
                        byte[] data = new byte[length];
                        for (int k = 0; k < length; ++k)
                        {
                            data[k] = Convert.ToByte(args[k + 2], 16);
                        }

                        int status = MainViewModel.IDbg.WriteEeprom(offset, data);
                        if (status != 0)
                        {
                            result = string.Format("Error writing EEPROM:{0}", MainViewModel.IErr.ErrorDescription(status));
                        }
                        else result = "WriteEEPROM OK";
                    }
                    else result = "MainViewModel.IDbg interface is null, can't execute anything";
                }
                catch (Exception ex)
                {
                    result = string.Format("Exception writing EEPROM:{0}", ex.Message);
                }
                return result;
            });
        }

        public ReactiveCommand<List<string>> CmdEEPROMtoFile { get; protected set; }
        IObservable<List<string>> CmdEEPROMtoFileRun()
        {
            return Observable.Start(() =>
            {
                List<string> results = new List<string>();
                try
                {
                    if (MainViewModel.IDbg != null)
                    {
                        int offset = 0;
                        int LENGTH = 3072;
                        byte[] buffer = new byte[LENGTH];
                        const int BYTES_PER_READ = 16;  // due to HID report size being 32
                        byte[] data = new byte[BYTES_PER_READ];
                        int count = LENGTH / BYTES_PER_READ;
                        if (LENGTH % BYTES_PER_READ > 0)
                            ++count;
                        for (int k = 0; k < count; ++k)
                        {
                            int status = MainViewModel.IDbg.ReadEeprom(offset, ref data);
                            if (status == 0)
                            {
                                Array.Copy(data, 0, buffer, offset, BYTES_PER_READ);
                                offset += BYTES_PER_READ;
                            }
                            else
                            {
                                results.Add(string.Format("Error reading EEPROM:{0}", MainViewModel.IErr.ErrorDescription(status)));
                                break;
                            }
                            Thread.Sleep(100); // MCU is slow
                        }

                        string filename = Environment.GetFolderPath(Environment.SpecialFolder.CommonDocuments) + "\\" + EepromFilename;
                        BinaryWriter bw = new BinaryWriter(new FileStream(filename, FileMode.Create));
                        if (bw != null)
                            bw.Write(buffer);
                        bw.Close();
                    }
                    else results.Add("MainViewModel.IDbg interface is null, can't execute anything");
                }
                catch (Exception ex)
                {
                    results.Add(string.Format("Exception dumping EEPROM to file:{0}", ex.Message));
                }
                return results;
            });
        }

        public ReactiveCommand<string> CmdFileToEEPROM { get; protected set; }
        IObservable<string> CmdFileToEEPROMRun()
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    if (MainViewModel.IDbg != null)
                    {
                        const int LENGTH = 3072;
                        byte[] buffer = new byte[LENGTH];

                        string filename = Environment.GetFolderPath(Environment.SpecialFolder.CommonDocuments) + "\\" + EepromFilename;
                        BinaryReader bw = new BinaryReader(new FileStream(filename, FileMode.Open));
                        if (bw != null)
                            bw.Read(buffer, 0, LENGTH);
                        bw.Close();

                        int offset = 0;
                        const int BYTES_PER_BLOCK = 16;  // due to HID report size being 32
                        byte[] data = new byte[BYTES_PER_BLOCK];
                        int count = LENGTH / BYTES_PER_BLOCK;
                        int status;
                        for (int k = 0; k < count; ++k)
                        {
                            Array.Copy(buffer, offset, data, 0, BYTES_PER_BLOCK);
                            if ((status = MainViewModel.IDbg.WriteEeprom(offset, data)) != 0)
                            {
                                result = string.Format("Error writing EEPROM:{0}", MainViewModel.IErr.ErrorDescription(status));
                                break;
                            }
                            offset += BYTES_PER_BLOCK;
                        }
                    }
                    else result = "MainViewModel.IDbg interface is null, can't execute anything";
                }
                catch (Exception ex)
                {
                    result = string.Format("Exception writing file to EEPROM:{0}", ex.Message);
                }
                return result;
            });
        }

        /// <summary>
        /// Does not support write before read yet
        /// </summary>
        public ReactiveCommand<List<string>> CmdReadI2C { get; protected set; }
        IObservable<List<string>> CmdReadI2CRun()
        {
            return Observable.Start(() =>
            {
                List<string> results = new List<string>();
                try
                {
                    if (MainViewModel.IDbg != null)
                    {
                        string[] args = ReadI2C.Split(new char[] { ' ', ',' });
                        if (ReadI2C == null || args.Length < 4)
                            throw new ApplicationException("ReadI2C format(hex):'CHNL ADR BYTES WrBeforeRdBYTES(Must be 0 or N) B0 B1 Bn'");

                        int channel = Convert.ToInt16(args[0], 16);
                        int address = Convert.ToInt16(args[1], 16);
                        int bytes = Convert.ToByte(args[2], 16);
                        int wr_bytes = args.Length > 3 ? Convert.ToInt16(args[3], 16) : 0;
                        byte[] wr_before_read = null;
                        if (wr_bytes > 0)
                        {
                            wr_before_read = new byte[wr_bytes];
                            for (int k = 0; k < wr_bytes; ++k)
                                wr_before_read[k] = Convert.ToByte(args[4 + k], 16);
                        }
                        const int MAX_BYTES = 26;
                        if (bytes > MAX_BYTES)
                            bytes = MAX_BYTES;
                        byte[] data = new byte[bytes];
                        int status = MainViewModel.IDbg.ReadI2C(channel, address, wr_before_read, data);
                        if (status == 0)
                        {
                            string result = "";
                            const int BYTES_PER_LINE = 13;
                            int count = bytes / BYTES_PER_LINE;
                            if (bytes % BYTES_PER_LINE > 0)
                                ++count;
                            int i;
                            for (int k = i = 0; k < count && i < bytes; ++k)
                            {
                                for (int j = 0; j < BYTES_PER_LINE; ++j)
                                {
                                    if (i < bytes)
                                        result += string.Format("  {0:x02}", data[i++]);
                                    else break;
                                }
                                results.Add(result);
                            }
                        }
                        else
                        {
                            results.Add(string.Format("Error reading I2C:{0}", MainViewModel.IErr.ErrorDescription(status)));
                        }
                    }
                    else results.Add("MainViewModel.IDbg interface is null, can't execute anything");
                }
                catch (Exception ex)
                {
                    results.Add(string.Format("Exception reading I2C:{0}", ex.Message));
                }
                return results;
            });
        }

        public ReactiveCommand<string> CmdWriteI2C { get; protected set; }
        IObservable<string> CmdWriteI2CRun()
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    if (MainViewModel.IDbg != null)
                    {
                        string[] args = WriteI2C.Split(new char[] { ' ', ',' });
                        if (WriteI2C == null || args.Length < 3)
                            throw new ApplicationException("WriteI2C format(hex):'CC AA NN B0 B1 Bn', C=channel, A=address, N=bytes, B0...Bn is data");

                        int channel = Convert.ToInt16(args[0], 16);
                        int address = Convert.ToInt16(args[1], 16);
                        int length = args.Length - 3;
                        byte[] data = new byte[length];
                        for (int k = 0; k < length; ++k)
                        {
                            data[k] = Convert.ToByte(args[k + 3], 16);
                        }
                        int status = MainViewModel.IDbg.WriteI2C(channel, address, data);
                        if (status != 0)
                        {
                            result = string.Format("Error writing I2C:{0}", MainViewModel.IErr.ErrorDescription(status));
                        }
                        else result = "WriteI2C OK";
                    }
                    else result = "MainViewModel.IDbg interface is null, can't execute anything";
                }
                catch (Exception ex)
                {
                    result = string.Format("Exception writing I2C:{0}", ex.Message);
                }
                return result;
            });
        }

        public ReactiveCommand<string> CmdWrRdSPI { get; protected set; }
        IObservable<string> CmdWrRdSPIRun()
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    if (MainViewModel.IDbg != null)
                    {
                        if (WrRdSPI == null)
                            throw new ApplicationException("WrRdSPI argument format(hex), 'Device# N Bytes'");

                        string[] args = WrRdSPI.Split(new char[] { ' ', ',' });
                        if (args.Length < 3)
                            throw new ApplicationException("WrRdSPI argument format(hex), 'Device# N Bytes'");

                        int device = Convert.ToInt16(args[0], 16);
                        int length = args.Length - 2;
                        byte[] data = new byte[length];
                        for (int k = 0; k < length; ++k)
                        {
                            data[k] = Convert.ToByte(args[k + 2], 16);
                        }
                        int status = MainViewModel.IDbg.WrRdSPI(device, ref data);
                        if (status != 0)
                        {
                            result = string.Format("SPI IO Error {0}", status);
                        }
                        else result = "WrRdSPI OK";
                    }
                    else result = "MainViewModel.IDbg interface is null, can't execute anything";
                }
                catch (Exception ex)
                {
                    result = string.Format("Exception in SPI IO:{0}", ex.Message);
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
                        if (value < 0.0 || value > 40.0)
                            return string.Format("Power out of range({0}) must be between 0 and 40 dB", value);
                        PwrInDb = value;
                        int status;
                        if ((status = MainViewModel.CalPanel.SetCalPower(PwrInDb)) == 0)
                            result = " Set PwrInDb Ok";
                        else result = string.Format(" Set PwrInDb failed:{0}", MainViewModel.IErr.ErrorDescription(status));
                    }
                    else
                        return string.Format("Error, cannot convert '{0}' to a double", text.ToString());
                }
                catch (Exception ex)
                {
                    result = string.Format("Set PwrInDb exception:{0}", ex.Message);
                }
                return result;
            });
        }

        public ReactiveCommand<string> CmdPwrCalTags { get; protected set; }
        IObservable<string> CmdPwrCalTagsRun()
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    string filename = Environment.GetFolderPath(Environment.SpecialFolder.CommonDocuments) + "\\" + EepromFilename;
                    int status;
                    List<PowerCalTag> tags = null;
                    if ((status = MainViewModel.IDbg.GetPowerCalTags(filename, ref tags)) == 0)
                    {
                        result = string.Format(" Read {0} tags from EEPROM.bin", tags.Count);
                        PowerCalTags = tags;
                    }
                    else result = string.Format(" Get PwrCalTags failed:{0}", MainViewModel.IErr.ErrorDescription(status));
                }
                catch (Exception ex)
                {
                    result = string.Format("Get PwrCalTags exception:{0}", ex.Message);
                }
                return result;
            });
        }

        readonly ObservableAsPropertyHelper<bool> _isTemperature;
        public bool IsTemperature { get { return _isTemperature.Value; } }
        public ReactiveCommand<string> CmdTemperatureData { get; protected set; }
        IObservable<string> CmdTemperatureDataRun()
        {
            // This will run for a long time to gather temperature/power change data
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    string dir = Environment.GetFolderPath(Environment.SpecialFolder.CommonDocuments) + "\\";
                    var now = DateTime.Now;
                    string filename = string.Format("{0}{1:d02}_{2:d02}_{3:d02}_{4:d02}_{5:d02}_{6:d02}_{7}",
                                                            dir, now.Year, now.Month, now.Day,
                                                            now.Hour, now.Minute, now.Second,
                                                            TemperatureFilename);
                    StreamWriter wr = new StreamWriter(filename, true);
                    wr.WriteLine("Timestamp,Temperature,Power");
                    TemperatureLoop = true;
                    while(TemperatureLoop)
                    {
                        int status;
                        MonitorPa[] results = new MonitorPa[1];
                        if ((status = MainViewModel.ICmd.PaStatus(0, ref results)) == 0)
                        {
                            double power = 55.0;
                            power = MainViewModel.CalPanel.ReadExternal(power);
                            string entry = string.Format("{0:d02}_{1:d02}_{2:d02}_{3:d02}_{4:d02}_{5:d02},{6},{7}",
                                                                    now.Year, now.Month, now.Day,
                                                                    now.Hour, now.Minute, now.Second,
                                                                    results[0].Temperature, power);
                            wr.WriteLine(entry);
                            // measure every 10 secs
                            for (int tmp = 0; tmp < 40; ++tmp)
                            {
                                Thread.Sleep(250);
                                if (!TemperatureLoop)
                                    break;
                            }
                        }
                        else
                        {
                            result = string.Format(" TemperatureData failed:{0}", MainViewModel.IErr.ErrorDescription(status));
                            TemperatureLoop = false;
                        }

                    }
                }
                catch (Exception ex)
                {
                    result = string.Format("TemperatureData exception:{0}", ex.Message);
                }
                return result;
            });
        }

        public ReactiveCommand<string> CmdStopTemperatureData { get; protected set; }
        IObservable<string> CmdStopTemperatureDataRun()
        {
            return Observable.Start(() =>
            {
                TemperatureLoop = false;
                return "Stopped temperature looping";
            });
        }

        public ReactiveCommand<string> CmdWritePwrCalTags { get; protected set; }
        IObservable<string> CmdWritePwrCalTagsRun()
        {
            return Observable.Start(() =>
            {
                string result = "";
                try
                {
                    string dir = Environment.GetFolderPath(Environment.SpecialFolder.CommonDocuments) + "\\";
                    string filename = dir + EepromFilename;
                    var now = DateTime.Now;
                    string bkpfile = dir + string.Format("{0:d02}_{1:d02}_{2:d02}_{3:d02}_{4:d02}_{5:d02}_EEPROMbkp.bin",
                                                            now.Year, now.Month, now.Day, 
                                                            now.Hour, now.Minute, now.Second);
                    int status;
                    if ((status = MainViewModel.IDbg.WritePowerCalTags(bkpfile, filename, PowerCalTags)) == 0)
                    {
                        result = string.Format(" Wrote {0} power cal tags to EEPROM.bin", PowerCalTags.Count);
                    }
                    else result = string.Format(" Set PwrCalTags failed:{0}", MainViewModel.IErr.ErrorDescription(status));
                }
                catch (Exception ex)
                {
                    result = string.Format("Set PwrCalTags exception:{0}", ex.Message);
                }
                return result;
            });
        }

        public void UpdateValues()
        {
            CmdReadDacsRun();
        }

        // props

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

        bool _temperatureLoop;
        public bool TemperatureLoop
        {
            get { return _temperatureLoop; }
            set { this.RaiseAndSetIfChanged(ref _temperatureLoop, value); }
        }

        ObservableCollection<ChannelViewModel> _channelVms;
        public ObservableCollection<ChannelViewModel> ChannelVms
        {
            get { return _channelVms; }
            set { this.RaiseAndSetIfChanged(ref _channelVms, value); }
        }

        string _example;
        public string Example
        {
            get { return _example; }
            set { this.RaiseAndSetIfChanged(ref _example, value); }
        }

        decimal _frequency;
        public decimal Frequency
        {
            get { return _frequency; }
            set { this.RaiseAndSetIfChanged(ref _frequency, value); }
        }

        decimal _power;
        public decimal Power
        {
            get { return _power; }
            set { this.RaiseAndSetIfChanged(ref _power, value); }
        }

        double _pwrInDb;
        public double PwrInDb
        {
            get { return _pwrInDb; }
            set { this.RaiseAndSetIfChanged(ref _pwrInDb, value); }
        }

        decimal _phase;
        public decimal Phase
        {
            get { return _phase; }
            set { this.RaiseAndSetIfChanged(ref _phase, value); }
        }

        int _pwm;
        public int PWM
        {
            get { return _pwm; }
            set { this.RaiseAndSetIfChanged(ref _pwm, value); }
        }

        int _interval;
        public int Interval
        {
            get { return _interval; }
            set { this.RaiseAndSetIfChanged(ref _interval, value); }
        }

        string _status;
        public string Status
        {
            get { return _status; }
            set { this.RaiseAndSetIfChanged(ref _status, value); }
        }

        string _runtimeResults;
        public string RuntimeResults
        {
            get { return _runtimeResults; }
            set { this.RaiseAndSetIfChanged(ref _runtimeResults, value); }
        }

        string _logText;
        public string LogText
        {
            get { return _logText; }
            set { this.RaiseAndSetIfChanged(ref _logText, value); }
        }

        string _cmdData;
        public string CmdData
        {
            get { return _cmdData; }
            set { this.RaiseAndSetIfChanged(ref _cmdData, value); }
        }

        string _getTag;
        public string GetTag
        {
            get { return _getTag; }
            set { this.RaiseAndSetIfChanged(ref _getTag, value); }
        }

        string _setTag;
        public string SetTag
        {
            get { return _setTag; }
            set { this.RaiseAndSetIfChanged(ref _setTag, value); }
        }
        string _tagData;
        public string TagData
        {
            get { return _tagData; }
            set { this.RaiseAndSetIfChanged(ref _tagData, value); }
        }

        string _readEEPROM;
        public string ReadEEPROM
        {
            get { return _readEEPROM; }
            set { this.RaiseAndSetIfChanged(ref _readEEPROM, value); }
        }

        string _writeEEPROM;
        public string WriteEEPROM
        {
            get { return _writeEEPROM; }
            set { this.RaiseAndSetIfChanged(ref _writeEEPROM, value); }
        }
        string _EEPROMData;
        public string EEPROMData
        {
            get { return _EEPROMData; }
            set { this.RaiseAndSetIfChanged(ref _EEPROMData, value); }
        }

        string _readI2C;
        public string ReadI2C
        {
            get { return _readI2C; }
            set { this.RaiseAndSetIfChanged(ref _readI2C, value); }
        }

        string _writeI2C;
        public string WriteI2C
        {
            get { return _writeI2C; }
            set { this.RaiseAndSetIfChanged(ref _writeI2C, value); }
        }

        string _wrrdSPI;
        public string WrRdSPI
        {
            get { return _wrrdSPI; }
            set { this.RaiseAndSetIfChanged(ref _wrrdSPI, value); }
        }

        List<PowerCalTag> _powerCalTags;
        public List<PowerCalTag> PowerCalTags
        {
            get { return _powerCalTags; }
            set { this.RaiseAndSetIfChanged(ref _powerCalTags, value); }
        }

        string _eepromFilename;
        public string EepromFilename
        {
            get { return _eepromFilename; }
            set { this.RaiseAndSetIfChanged(ref _eepromFilename, value); }
        }

        string _temperatureFilename;
        public string TemperatureFilename
        {
            get { return _temperatureFilename; }
            set { this.RaiseAndSetIfChanged(ref _temperatureFilename, value); }
        }


    }
}
