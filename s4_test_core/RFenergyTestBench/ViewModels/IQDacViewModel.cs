using System;
using System.Reactive.Linq;
using ReactiveUI;
using System.Threading.Tasks;
using System.Reactive.Disposables;
using M2TestModule;

namespace RFenergyUI.ViewModels
{
    /// <summary>
    /// SPI IQ Dac
    /// </summary>
    public enum IqDac
    {
        DacI,
        DacQ
    }

    public class IQDacViewModel : ReactiveObject
    {
        const double VOLTS_PER_LSB = 3.3 / 4095.0;
        const int DEVICE_DAC = M2FwDefs.IQDAC;   // M2 SPI device 9 is Synthesizer IQ DAC

        static object _runLock = new object();

        public IQDacViewModel()
        {
            LogFile = MainViewModel.MainLogFile;
            Channel = -1;

            CmdDacValue = ReactiveCommand.CreateAsyncObservable(x => CmdDacRun());
            CmdDacValue.Subscribe(result => MainViewModel.MsgAppendLine(result));
            CmdDacBits = ReactiveCommand.CreateAsyncObservable(x => CmdBinaryDacRun());
            CmdDacBits.Subscribe(result => MainViewModel.MsgAppendLine(result));
            CmdDacValueArrow = ReactiveCommand.CreateAsyncObservable(x => CmdDacValueArrowRun(x));
            CmdDacValueArrow.Subscribe(result => MainViewModel.MsgAppendLine(result));
            CmdDacArrow = ReactiveCommand.CreateAsyncObservable(x => CmdDacArrowRun(x));
            CmdDacArrow.Subscribe(result => MainViewModel.MsgAppendLine(result));
        }

        // properties

        IqDac _whichDac;
        public IqDac WhichDac
        {
            get { return _whichDac; }
            set { this.RaiseAndSetIfChanged(ref _whichDac, value); }
        }

        bool _showChannel;
        public bool ShowChannel
        {
            get { return _showChannel; }
            set { this.RaiseAndSetIfChanged(ref _showChannel, value); }
        }

        int _channel;
        public int Channel
        {
            get { return _channel; }
            set { this.RaiseAndSetIfChanged(ref _channel, value); }
        }

        string _title;
        public string Title
        {
            get { return _title; }
            set { this.RaiseAndSetIfChanged(ref _title, value); }
        }

        double _dacvalue;
        public double DacValue
        {
            get { return _dacvalue; }
            set { this.RaiseAndSetIfChanged(ref _dacvalue, value); }
        }

        ushort _dacbits;
        public ushort DacBits
        {
            get { return _dacbits; }
            set { this.RaiseAndSetIfChanged(ref _dacbits, value); }
        }

        // commands

        public ReactiveCommand<string> CmdDacValue { get; protected set; }
        IObservable<string> CmdDacRun()
        {
            string result = "";
            try
            {
                DacBits = (ushort)(DacValue / VOLTS_PER_LSB);
                return CmdBinaryDacRun();
            }
            catch (Exception ex)
            {
                result = string.Format("IQDAC write exception:{0}", ex.Message);
            }
            return Observable.Return(result);
        }

        public ReactiveCommand<string> CmdDacBits { get; protected set; }
        IObservable<string> CmdBinaryDacRun()
        {
            return Observable.Create<string>(obs =>
            {
                bool stopEarly = false;
                Task.Run(() =>
                {
                    lock(_runLock)  // One at a time...
                    {
                        try
                        {
                            int value;
                            string descrip = "";

                            value = DacBits & 0xfff;
                            DacValue = value * VOLTS_PER_LSB;
                            switch (WhichDac)
                            {
                                default:
                                case IqDac.DacI:
                                    descrip = "DacI";
                                    break;
                                case IqDac.DacQ:
                                    descrip = "DacQ";
                                    break;
                            }
                            if (MainViewModel.IDbg != null)
                            {
                                byte[] data = new byte[3];
                                data[0] = WhichDac == IqDac.DacI ? (byte)0 : (byte)0x11;
                                // Must swap bytes when programming IQ Dac. 
                                // SPI driver sends LSB first, device requires MSB first
                                data[1] = (byte)((value >> 4) & 0xff);
                                data[2] = (byte)((value & 0xff) << 4);
                                int status = MainViewModel.IDbg.WrRdSPI(DEVICE_DAC, ref data);
                                if (status == 0)
                                {
                                    obs.OnNext(string.Format(" IQDac {0} binary write Ok", descrip));
                                }
                                else obs.OnNext(string.Format(" IQDac {0} binary write failed:{1}", descrip, MainViewModel.IErr.ErrorDescription(status)));
                            }
                            else obs.OnNext("IDbg interface is null, can't execute anything");
                        }
                        catch (Exception ex)
                        {
                            obs.OnNext(string.Format("CmdDacBits exception:{0}", ex.Message));
                        }
                        obs.OnCompleted();
                    }
                });
                return Disposable.Create(() => stopEarly = true);
            });
        }

        /// <summary>
        /// Runs on the UI thread
        /// </summary>
        public ReactiveCommand<string> CmdDacValueArrow { get; protected set; }
        IObservable<string> CmdDacValueArrowRun(object arrow)
        {
            string result = "";
            try
            {
                double delta = arrow.ToString().StartsWith("up") ? VOLTS_PER_LSB : -VOLTS_PER_LSB;
                DacValue += delta;
                return CmdDacRun();
            }
            catch (Exception ex)
            {
                result = string.Format("IQ DacValueArrow write exception:{0}", ex.Message);
            }
            return Observable.Return(result);
        }

        /// <summary>
        /// This is running on the UI thread
        /// </summary>
        public ReactiveCommand<string> CmdDacArrow { get; protected set; }
        IObservable<string> CmdDacArrowRun(object arrow)
        {
            string result = "";
            try
            {
                if((arrow.ToString().StartsWith("up") && DacBits < 0xfff) ||
                    (arrow.ToString().StartsWith("down") && DacBits > 0))
                {
                    if (arrow.ToString().StartsWith("down"))
                        DacBits -= 1;
                    else DacBits += 1;
                    return CmdBinaryDacRun();
                }
                return Observable.Return("IQ Dac at range limit, no change");
            }
            catch (Exception ex)
            {
                result = string.Format("IQ DacValueArrow write exception:{0}", ex.Message);
            }
            return Observable.Return(result);
        }

        string LogFile { get; set; }
    }
}
