using System;
using ReactiveUI;
using M2TestModule;

namespace RFenergyUI.ViewModels
{
    public class PaViewModel : ReactiveObject
    {
        public PaViewModel()
        {
            Channel = 1;

            //this.WhenAny(x => x.Channel, x => x.GetValue() == 1)
            //    .ToProperty(this, x => x.ShowChannel, out _showChannel);
        }

        // properties

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

        double _temperature;
        public double Temperature
        {
            get { return _temperature; }
            set { this.RaiseAndSetIfChanged(ref _temperature, value); }
        }

        double _voltage;
        public double Voltage
        {
            get { return _voltage; }
            set { this.RaiseAndSetIfChanged(ref _voltage, value); }
        }

        double _current;
        public double Current
        {
            get { return _current; }
            set { this.RaiseAndSetIfChanged(ref _current, value); }
        }

        double _idrv;
        public double IDrv
        {
            get { return _idrv; }
            set { this.RaiseAndSetIfChanged(ref _idrv, value); }
        }
    }
}
