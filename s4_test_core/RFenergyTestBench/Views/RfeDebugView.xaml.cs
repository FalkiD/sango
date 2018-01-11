using System;
using System.Windows;
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
        bool _initVm;

        public RfeDebugView()
        {
            _vm = new RfeDebugViewModel(this);
            DataContext = _vm;     // Bindings
            InitializeComponent();
            _initVm = true;
        }

        void Window_Loaded(object sender, RoutedEventArgs e)
        {
            try
            {
                if (_initVm)
                {
                    _vm.SetupHardware();
                    _initVm = false;
                }
            }
            catch (Exception ex)
            {
                MainViewModel.MsgAppendLine(string.Format("OnLoad exception:{0}", ex.Message));
            }
        }
    }
}
