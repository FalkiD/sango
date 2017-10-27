/*
 * Naming is a mess when used on S4, need to divorce
 * the hardware usage from this ViewModel.
 * 
 * For S4 usage, due to placement on View: 
 *  BIAS1A is M2 PhaseDac
 *  BIAS1B is M2 GainDac
 *  BIAS2A is Bias1
 *  BIAS2B is Bias2
 */


using ReactiveUI;

namespace RFenergyUI.ViewModels
{
    public class ChannelViewModel : ReactiveObject
    {
        int _number;
        public int Number
        {
            get { return _number; }
            set { this.RaiseAndSetIfChanged(ref _number, value); }
        }

        bool _selected;
        public bool IsSelected
        {
            get { return _selected; }
            set { this.RaiseAndSetIfChanged(ref _selected, value); }
        }

        DacViewModel _bias1DacVm;
        public DacViewModel Bias1DacVm
        {
            get { return _bias1DacVm; }
            set { this.RaiseAndSetIfChanged(ref _bias1DacVm, value); }
        }

        DacViewModel _bias2DacVm;
        public DacViewModel Bias2DacVm
        {
            get { return _bias2DacVm; }
            set { this.RaiseAndSetIfChanged(ref _bias2DacVm, value); }
        }

        DacViewModel _phaseDacVm;
        public DacViewModel PhaseDacVm
        {
            get { return _phaseDacVm; }
            set { this.RaiseAndSetIfChanged(ref _phaseDacVm, value); }
        }

        DacViewModel _gainDacVm;
        public DacViewModel GainDacVm
        {
            get { return _gainDacVm; }
            set { this.RaiseAndSetIfChanged(ref _gainDacVm, value); }
        }

        PaViewModel _paVm;
        public PaViewModel PaVm
        {
            get { return _paVm; }
            set { this.RaiseAndSetIfChanged(ref _paVm, value); }
        }

        // Confusing, S4 uses above 4 DacViewModels for MCP4728 quad DAC
        // This additional vm controls the S4 PA MCP4726 single-channel DAC
        DacViewModel _s4PaVm;
        public DacViewModel S4PaVm
        {
            get { return _s4PaVm; }
            set { this.RaiseAndSetIfChanged(ref _s4PaVm, value); }
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
    }
}
