using System;
using System.Windows;
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
        bool _initVm;

        public CalView()
        {
            _vm = new CalViewModel(this);
            DataContext = _vm;     // Bindings
            InitializeComponent();
            _initVm = true;
        }

        // startup operations after windows have been created
        void Window_Loaded(object sender, RoutedEventArgs e)
        {
            try
            {
                if(_initVm)
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
