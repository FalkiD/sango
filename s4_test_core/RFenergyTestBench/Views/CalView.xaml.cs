using System.Windows.Controls;
using RFenergyUI.ViewModels;

namespace RFenergyUI.Views
{
    /// <summary>
    /// Interaction logic for RfeDebugView.xaml
    /// </summary>
    public partial class CalView : UserControl
    {
        CalViewModel _vm;

        public CalView()
        {
            _vm = new CalViewModel(this);
            DataContext = _vm;     // Bindings
            InitializeComponent();
        }
    }
}
