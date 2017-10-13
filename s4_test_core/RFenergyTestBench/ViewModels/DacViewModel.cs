/*
 * Microchip MCP4728 ViewModel
 * Using Single Write Command, Figure 5-9 in datasheet
 * C2=0, C1=1, C0=0, W1=1, W0=1
 * 
 * Byte 2(after I2C address) = 0x58, 5a, 5c, 5e
 * Byte 3 top nibble=9 (Vref, Gx)
 * 
 * On S4 this only works for the driver module, DAC's have different uses,
 * need to completly divorce this from hardware layer.
 * S4 driver they are BIAS1A, BIAS1B, BIAS2A, BIAS2B
 * 
 */
using System;
using System.Reactive.Linq;
using ReactiveUI;

namespace RFenergyUI.ViewModels
{
    /// <summary>
    /// The I2C DACs only
    /// </summary>
    public enum Dac
    {
        ePhaseTrim,
        eGainTrim,
        eBias1,
        eBias2
    }

    public class DacViewModel : ReactiveObject
    {
        // Microchip 4728, internal reference, Gain bit set(gain=2)
        const double VOLTS_PER_LSB = 0.001;
        const int CMD_BYTE_BASE = 0x58; // or in channel 0-3
        const int BYTE3_BASE = 0x90;    // or in 4 MSB's data

        public DacViewModel()
        {
            LogFile = MainViewModel.MainLogFile;
            Channel = 1;

            CmdRead = ReactiveCommand.CreateAsyncObservable(x => CmdReadDacRun());
            CmdRead.Subscribe(result => MainViewModel.MsgAppendLine(result));

            CmdDacValue = ReactiveCommand.CreateAsyncObservable(x => CmdDacRun(x));
            CmdDacValue.Subscribe(result => MainViewModel.MsgAppendLine(result));
            CmdDacBits = ReactiveCommand.CreateAsyncObservable(x => CmdBinaryDacRun(x));
            CmdDacBits.Subscribe(result => MainViewModel.MsgAppendLine(result));
            CmdDacArrow = ReactiveCommand.CreateAsyncObservable(x => CmdDacArrowRun(x));
            CmdDacArrow.Subscribe(result => MainViewModel.MsgAppendLine(result));
            CmdDacValueArrow = ReactiveCommand.CreateAsyncObservable(x => CmdDacValueArrowRun(x));
            CmdDacValueArrow.Subscribe(result => MainViewModel.MsgAppendLine(result));

            //this.WhenAny(x => x.Channel, x => x.GetValue() == 1)
            //    .ToProperty(this, x => x.ShowChannel, out _showChannel);
        }

        // properties

        Dac _whichDac;
        public Dac WhichDac
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
        public ReactiveCommand<string> CmdRead { get; protected set; }
        IObservable<string> CmdReadDacRun()
        {
            string result = "";
            int channel = 1;
            try
            {
                if (MainViewModel.IDbg != null)
                {
                    byte[] data = new byte[24];
                    int status = 0;
                    status = MainViewModel.IDbg.ReadI2C(channel, 0x60, null, data);
                    if (status == 0)
                    {
                        if (data.Length == 24)
                        {
                            int offset = 1 + ((_channel - 1) * 6);
                            int value = (data[offset+1] | ((data[offset] & 0xf) << 8)) & 0xfff;
                            DacValue = value * VOLTS_PER_LSB;
                            DacBits = (ushort)value;
                            result = string.Format(" Channel {0} ReadDAC Ok", channel);
                        }
                        else result = string.Format(" Channel {0} ReadDAC failed to read 0x18 bytes, read:{1}", channel, data.Length);
                    }
                    else result = string.Format(" Channel {0} Dac read failed:{1}", channel, MainViewModel.IErr.ErrorDescription(status));
                }
                else result = "IDbg interface is null, can't execute anything";
            }
            catch (Exception ex)
            {
                result = string.Format("CmdRead{0} Exception:{1}", channel, ex.Message);
            }
            return Observable.Return(result);
        }

        public ReactiveCommand<string> CmdDacValue { get; protected set; }
        IObservable<string> CmdDacRun(object text)
        {
            string result = "";
            try
            {
                double value;
                if (Double.TryParse(text.ToString(), out value))
                {
                    DacValue = value;
                    if (DacValue < 0.0 || DacValue > 4.095)
                        return Observable.Return(string.Format("Invalid Dac value({0}) must be between 0 and 4.095", DacValue));
                    DacBits = (ushort)(((int)(DacValue / VOLTS_PER_LSB)) & 0xfff);
                    return CmdBinaryDacRun(string.Format("{0:x}", DacBits));
                }
                else
                    return Observable.Return(string.Format("Error, cannot convert '{0}' to a double", text.ToString()));
            }
            catch (Exception ex)
            {
                result = string.Format("DAC write exception:{0}", ex.Message);
            }
            return Observable.Return(result);
        }

        public ReactiveCommand<string> CmdDacValueArrow { get; protected set; }
        IObservable<string> CmdDacValueArrowRun(object arrow)
        {
            string result = "";
            try
            {
                double delta = arrow.ToString().StartsWith("up") ? VOLTS_PER_LSB : -VOLTS_PER_LSB;
                DacValue += delta;
                return CmdDacRun(DacValue.ToString());
            }
            catch (Exception ex)
            {
                result = string.Format("DacValueArrow write exception:{0}", ex.Message);
            }
            return Observable.Return(result);
        }

        public ReactiveCommand<string> CmdDacBits { get; protected set; }
        IObservable<string> CmdBinaryDacRun(object text)
        {
            string result = "";
            try
            {
                uint value = Convert.ToUInt32(text as string, 16);
                if (value >= 0 && value <= 4095)
                {
                    string descrip = "";
                    byte chnl;
                    DacBits = (ushort)(value & 0xfff);
                    DacValue = value * VOLTS_PER_LSB;
                    switch (WhichDac)
                    {
                        case Dac.ePhaseTrim:
                            chnl = CMD_BYTE_BASE;    // Single-write command, channel A
                            descrip = "Phase/S4_1A";
                            break;
                        case Dac.eGainTrim:
                            chnl = CMD_BYTE_BASE | 2;    // Single-write command, channel B
                            descrip = "Gain/S4_1B";
                            break;
                        default:
                        case Dac.eBias1:
                            chnl = CMD_BYTE_BASE | 4;    // Single-write command, channel C
                            descrip = "Bias1/S4_2A";
                            break;
                        case Dac.eBias2:
                            chnl = CMD_BYTE_BASE | 6;    // Single-write command, channel D
                            descrip = "Bias2/S4_2B";
                            break;
                    }
                    if (MainViewModel.IDbg != null)
                    {
                        byte[] data = new byte[3];
                        data[0] = chnl;
                        data[1] = (byte)(((value & 0x0f00) >> 8) | BYTE3_BASE);
                        data[2] = (byte)(value & 0xff);
                        int status = MainViewModel.IDbg.WriteI2C(_channel, MainViewModel.IDbg.Mcp4728Address, data);
                        if (status == 0)
                        {
                            result = string.Format(" Wrote channel {0} {1} Dac {2:x02} {3:x02} {4:x02} ",
                                                        _channel, descrip, data[0], data[1], data[2]);
                        }
                        else result = string.Format(" {0} {1} binary write failed:{2}", _channel, descrip, MainViewModel.IErr.ErrorDescription(status));
                    }
                    else result = "IDbg interface is null, can't execute anything";
                }
                else result = string.Format("Invalid Dac bit value({0:x}) must be between 0 and 4095(0xfff)", value);    
            }
            catch (Exception ex)
            {
                result = string.Format("DAC write exception:{0}", ex.Message);
            }
            return Observable.Return(result);
        }

        public ReactiveCommand<string> CmdDacArrow { get; protected set; }
        IObservable<string> CmdDacArrowRun(object arrow)
        {
            string result = "";
            try
            {
                if ((arrow.ToString().StartsWith("up") && DacBits < 0xfff) ||
                    (arrow.ToString().StartsWith("down") && DacBits > 0))
                {
                    if (arrow.ToString().StartsWith("down"))
                        DacBits -= 1;
                    else DacBits += 1;
                    return CmdBinaryDacRun(null);
                }
                return Observable.Return("Dac at range limit, no change");
            }
            catch (Exception ex)
            {
                result = string.Format("DacArrow write exception:{0}", ex.Message);
            }
            return Observable.Return(result);
        }

        string LogFile { get; set; }
    }

}
