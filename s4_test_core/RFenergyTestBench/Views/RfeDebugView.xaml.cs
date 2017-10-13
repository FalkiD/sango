using System.Windows.Controls;
using RFenergyUI.ViewModels;

namespace RFenergyUI.Views
{
    /// <summary>
    /// Interaction logic for RfeDebugView.xaml
    /// </summary>
    public partial class RfeDebugView : UserControl
    {
        RfeDebugViewModel _vm;

        public RfeDebugView()
        {
            _vm = new RfeDebugViewModel(this);
            DataContext = _vm;     // Bindings
            InitializeComponent();
        }
    }
}
