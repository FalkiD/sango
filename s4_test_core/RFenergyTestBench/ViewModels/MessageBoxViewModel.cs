using System;
using System.Reactive.Linq;
using System.Windows;
using ReactiveUI;
using ReactiveUI.Routing;
using ReactiveUI.Xaml;
using Ninject.Extensions.Logging;

namespace ScUiCore.ViewModels
{
	// ReSharper disable FieldCanBeMadeReadOnly.Local
	// ReSharper disable InconsistentNaming
	// ReSharper disable ConvertToConstant.Local
	// ReSharper disable UnassignedField.Local
	public class MessageBoxViewModel
		: ReactiveObject
		, IRoutableViewModel
		, IDialog
	{
		ILogger Logger { get; set; }
	
		public MessageBoxViewModel(ILogger logger)
		{
			HostScreen = null;
			Title = "Title";
			Prompt = "Yes/No";
			Buttons = MessageBoxButton.OK;

			Logger = logger;

			SetupHandlersNo();
			SetupHandlersCancel();
			SetupHandlersYesOk();
			SetupHandlersClosed();
		}

		// IRoutableViewModel implementation
		public string UrlPathSegment { get { return Title; } }
		public IScreen HostScreen { get; private set; }

		// IAmDialogBox impementation
		public IRoutingState Router { get; set; }
		public IObservable<object> Closed { get; private set; }
		public string Title { get; set; }

		// public

		string _Prompt = string.Empty;
		public string Prompt
		{
			get { return _Prompt; }
			set { this.RaiseAndSetIfChanged( value ); }
		}

		MessageBoxResult _Result = MessageBoxResult.None;
		public MessageBoxResult Result
		{
			get { return _Result; }
			set { this.RaiseAndSetIfChanged( value ); }
		}

		MessageBoxButton _Buttons = MessageBoxButton.YesNoCancel;
		public MessageBoxButton Buttons
		{
			get { return _Buttons; }
			set { this.RaiseAndSetIfChanged( value ); }
		}

		ObservableAsPropertyHelper<bool> _ShowNo = null;
		public bool ShowNo
		{
			get { return _ShowNo.Value; }
		}

		ObservableAsPropertyHelper<bool> _ShowCancel = null;
		public bool ShowCancel
		{
			get { return _ShowCancel.Value; }
		}

		ObservableAsPropertyHelper<string> _YesOkText = null;
		public string YesOkText
		{
			get
			{
				return _YesOkText.Value;
			}
		}

		public ReactiveCommand YesOk { get; protected set; }
		public ReactiveCommand No { get; protected set; }
		public ReactiveCommand Cancel { get; protected set; }

		// support meth

		void SetupHandlersYesOk()
		{
			// observe the button type to set the YesOk button's text
			var iamYes = this.ObservableForProperty( x => x.Buttons,
													 x => ( x == MessageBoxButton.YesNo )
														  || ( x == MessageBoxButton.YesNoCancel ) );
			var yestext = this.ObservableForProperty( x => x.Buttons,
										x => ( x == MessageBoxButton.YesNo ) || ( x == MessageBoxButton.YesNoCancel )
												 ? "Yes" : "OK" );
			_YesOkText = new ObservableAsPropertyHelper<string>( yestext, x => this.RaisePropertyChanged( model => model.YesOkText ),
																 "OK" );

			// set the Yes or OK to No if pressed depending on Buttons configuration
			YesOk = new ReactiveCommand( iamYes );
			YesOk.Subscribe( e =>
			{
				Result = ( Buttons == MessageBoxButton.YesNo )
						 || ( Buttons == MessageBoxButton.YesNoCancel )
							 ? MessageBoxResult.Yes
							 : MessageBoxResult.OK;
			} );
		}
		void SetupHandlersCancel()
		{
			// observe button change to enable/disable the Cancel command 
			var enableCancel = this.ObservableForProperty(
				x => x.Buttons,
				x => ( x == MessageBoxButton.OKCancel ) || ( x == MessageBoxButton.YesNoCancel )
				).ToProperty( this, model => model.ShowCancel );

			Cancel = new ReactiveCommand( enableCancel );
			// set the Result to Cancel if pressed
			Cancel.Subscribe( e => Result = MessageBoxResult.Cancel );
		}
		void SetupHandlersNo()
		{
			// observe button change to enable/disable the No command 
			var enabledNo = this.ObservableForProperty(
				x => x.Buttons,
				x => ( x == MessageBoxButton.YesNo ) || ( x == MessageBoxButton.YesNoCancel )
				).ToProperty( this, model => model.ShowNo );

			No = new ReactiveCommand( enabledNo );
			// set the Result to No if pressed
			No.Subscribe( e => Result = MessageBoxResult.No );
		}
		void SetupHandlersClosed()
		{
			// calling any of the 3 button calls the Closed
			Closed = Observable.Merge( Cancel, YesOk, No );
			Closed.Subscribe(
				e =>
				{
					Logger.Warn( "{0} selected on prompt: {1}", Result, Prompt );
					if ( Router != null )
						Router.NavigateBack.Execute( Result );
				} );
		}
	}
	// ReSharper restore FieldCanBeMadeReadOnly.Local
	// ReSharper restore InconsistentNaming
	// ReSharper restore ConvertToConstant.Local
	// ReSharper restore UnassignedField.Local
}
