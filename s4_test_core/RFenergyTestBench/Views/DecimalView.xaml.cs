using System.Windows;
using ReactiveUI;
using ScUiCore.ViewModels;

namespace ScUiCore.Views
{
	/// <summary>
	/// Interaction logic for DecimalView.xaml
	/// </summary>
	public partial class DecimalView
		: IViewFor<FloatViewModel>
	{
		public DecimalView()
		{
			InitializeComponent();
		}

		// IViewFor implementation

		public FloatViewModel ViewModel
		{
			get { return (FloatViewModel)GetValue(ViewModelProperty); }
			set { SetValue(ViewModelProperty, value); }
		}

		public static readonly DependencyProperty ViewModelProperty =
			DependencyProperty.Register("ViewModel", typeof(FloatViewModel), typeof(DecimalView),
										 new PropertyMetadata(null));

		object IViewFor.ViewModel
		{
			get { return ViewModel; }
			set
			{
				DataContext = value;
				ViewModel = (FloatViewModel)value;
			}
		}
	}
}
