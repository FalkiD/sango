using System.Windows.Media;
using BusinessObjects;
using ReactiveUI;
using ReactiveUI.Routing;

namespace ScUiCore.ViewModels
{
    // ReSharper disable ConvertToConstant.Local
    // ReSharper disable FieldCanBeMadeReadOnly.Local
    // ReSharper disable InconsistentNaming
    public class StatusLedViewModel
        : ReactiveObject
        , IRoutableViewModel
    {
        readonly SolidColorBrush COLOR_NONE;
        readonly SolidColorBrush COLOR_WARNING;
        readonly SolidColorBrush COLOR_FAULT;

        public StatusLedViewModel(IScreen screen)
        {
            HostScreen = screen;

            COLOR_NONE = new SolidColorBrush()
                {
                    Color = Color.FromRgb(210, 210, 210)
                };
            COLOR_WARNING = new SolidColorBrush()
                {
                    Color = Color.FromRgb(255, 255, 0)
                };
            COLOR_FAULT = new SolidColorBrush()
                {
                    Color = Color.FromRgb(255, 0, 0)
                };
        }

        // IRoutableViewModel implementation

        public IScreen HostScreen { get; private set; }
        public string UrlPathSegment
        {
            get { return "StatusLedViewModel"; }
        }

        public void SetColor(ControllerFaultLevel faultLevel)
        {
            switch (faultLevel)
            {
                case (ControllerFaultLevel.Fault):
                    FillColor = COLOR_FAULT;
                    break;
                case (ControllerFaultLevel.Warning):
                    FillColor = COLOR_WARNING;
                    break;
                case (ControllerFaultLevel.None):
                default:
                    FillColor = COLOR_NONE;
                    break;
            }
        }

        // properties

        Brush _FillColor = null;
        public Brush FillColor
        {
            get { return _FillColor; }
            set { this.RaiseAndSetIfChanged(value); }
        }
    }
}
// ReSharper restore ConvertToConstant.Local
// ReSharper restore FieldCanBeMadeReadOnly.Local
// ReSharper restore InconsistentNaming
