using ReactiveUI;
using ReactiveUI.Routing;
using Ninject.Extensions.Logging;

namespace ScUiCore.ViewModels
{
	// ReSharper disable ConvertToConstant.Local
	// ReSharper disable FieldCanBeMadeReadOnly.Local
	// ReSharper disable InconsistentNaming
	public class DecimalViewModel
		: ReactiveObject
		, IRoutableViewModel
	{
		ILogger Logger { get; set; }

		public DecimalViewModel(IScreen screen, ILogger logger)
		{
			HostScreen = screen;
			Logger = logger;

		}

		// IRoutableViewModel implementation

		public IScreen HostScreen { get; private set; }
		public string UrlPathSegment
		{
			get { return "DecimalViewModel"; }
		}

		// properties

		decimal _Value = 0;
		public decimal Value
		{
			get { return _Value; }
			set { this.RaiseAndSetIfChanged(value); }
		}

		string _TextLabel = "Decimal Value:";
		public string TextLabel
		{
			get { return _TextLabel; }
			set { this.RaiseAndSetIfChanged(value); }
		}
	}
	// ReSharper restore ConvertToConstant.Local
	// ReSharper restore FieldCanBeMadeReadOnly.Local
	// ReSharper restore InconsistentNaming
}
