using System.Windows;
using ReactiveUI;
using ScUiCore.ViewModels;

namespace ScUiCore.Views
{
	/// <summary>
	/// Interaction logic for FloatView.xaml
	/// </summary>
	public partial class FloatView
		: IViewFor<FloatViewModel>
	{
		public FloatView()
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
			DependencyProperty.Register("ViewModel", typeof(FloatViewModel), typeof(FloatView),
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
