using System.Windows;
using System.Windows.Input;
using ReactiveUI;
using ScUiCore.ViewModels;

namespace ScUiCore.Views
{
    /// <summary>
    /// Interaction logic for DemoView.xaml
    /// </summary>
    public partial class DemoView
        : IViewFor<DemoViewModel>
    {
        public DemoView()
        {
            InitializeComponent();
        }

        // IViewFor implementation

        public DemoViewModel ViewModel
        {
            get { return (DemoViewModel)GetValue(ViewModelProperty); }
            set { SetValue(ViewModelProperty, value); }
        }

        public static readonly DependencyProperty ViewModelProperty =
            DependencyProperty.Register("ViewModel", typeof(DemoViewModel), typeof(DemoView),
                                         new PropertyMetadata(null));

        object IViewFor.ViewModel
        {
            get { return ViewModel; }
            set
            {
                DataContext = value;
                ViewModel = (DemoViewModel)value;
            }
        }

        void ScrollViewerItems_OnManipulationBoundaryFeedback(object sender, ManipulationBoundaryFeedbackEventArgs e)
        {
            e.Handled = true;
        }
    }
}
