using System.Windows;
using ReactiveUI;
using ScUiCore.ViewModels;

namespace ScUiCore.Views
{
	/// <summary>
	/// Interaction logic for MessageBoxView.xaml
	/// </summary>
	public partial class MessageBoxView
		: IViewFor<MessageBoxViewModel>
	{
		public MessageBoxView()
		{
			InitializeComponent();
		}

		// IViewFor implmentation

		object IViewFor.ViewModel
		{
			get { return ViewModel; }
			set
			{
				ViewModel = (MessageBoxViewModel) value;
				DataContext = ViewModel;
			}
		}
		public static readonly DependencyProperty ViewModelProperty =
			DependencyProperty.Register( "ViewModel", typeof( MessageBoxViewModel ), typeof( MessageBoxView ),
										 new PropertyMetadata( null ) );
		public MessageBoxViewModel ViewModel { get; set; }
	}
}
