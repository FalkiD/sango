using System.Windows;
using ReactiveUI;
using ScUiCore.ViewModels;

namespace ScUiCore.Views
{
    /// <summary>
    /// Interaction logic for StatusLedView.xaml
    /// </summary>
    public partial class StatusLedView
        : IViewFor<StatusLedViewModel>
    {
        public StatusLedView()
        {
            InitializeComponent();
        }

        // IViewFor implementation

        public StatusLedViewModel ViewModel
        {
            get { return (StatusLedViewModel)GetValue(ViewModelProperty); }
            set { SetValue(ViewModelProperty, value); }
        }

        public static readonly DependencyProperty ViewModelProperty =
            DependencyProperty.Register("ViewModel", typeof(StatusLedViewModel), typeof(StatusLedView),
                                         new PropertyMetadata(null));

        object IViewFor.ViewModel
        {
            get { return ViewModel; }
            set
            {
                DataContext = value;
                ViewModel = (StatusLedViewModel)value;
            }
        }
    }
}
