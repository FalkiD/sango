using ReactiveUI;
using ReactiveUI.Routing;
using Ninject.Extensions.Logging;

namespace ScUiCore.ViewModels
{
    // ReSharper disable ConvertToConstant.Local
    // ReSharper disable FieldCanBeMadeReadOnly.Local
    // ReSharper disable InconsistentNaming
    public class FloatViewModel
        : ReactiveObject
        , IRoutableViewModel
    {
        ILogger Logger
        {
            get;
            set;
        }

        public FloatViewModel ( IScreen screen, ILogger logger )
        {
            HostScreen = screen;
            Logger = logger;

        }

        // IRoutableViewModel implementation

        public IScreen HostScreen
        {
            get;
            private set;
        }
        public string UrlPathSegment
        {
            get
            {
                return "FloatViewModel";
            }
        }

        // properties

        float _Value = 0;
        public float Value
        {
            get
            {
                return _Value;
            }
            set
            {
                this.RaiseAndSetIfChanged ( value );
            }
        }

        string _TextLabel = "Float Value:";
        public string TextLabel
        {
            get
            {
                return _TextLabel;
            }
            set
            {
                this.RaiseAndSetIfChanged ( value );
            }
        }
    }
}
	// ReSharper restore ConvertToConstant.Local
	// ReSharper restore FieldCanBeMadeReadOnly.Local
	// ReSharper restore InconsistentNaming
