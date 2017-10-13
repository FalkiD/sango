using System.Windows;
using System.Windows.Controls;
using System.Windows.Threading;
using RFenergyUI.ViewModels;

namespace RFenergyUI.Views
{
    /// <summary>
    /// Interaction logic for TestView.xaml
    /// </summary>
    public partial class TestView : UserControl
    {
        TestViewModel _vm;
        DispatcherTimer _timer;

        public TestView()
        {
            if (System.ComponentModel.DesignerProperties.GetIsInDesignMode(this))
                return;

            _timer = new DispatcherTimer();
            _timer.Tick += _timer_Tick;
            _timer.Interval = new System.TimeSpan(0, 0, 0, 0, 750);

            _vm = new TestViewModel(this);
            DataContext = _vm;     // Bindings

            InitializeComponent();
        }

        void _timer_Tick(object sender, System.EventArgs e)
        {
            if (_vm != null)
                _vm.TimerTick();   
        }

        private void TestView_LayoutUpdated(object sender, System.EventArgs e)
        {
            //if (this.ActualHeight > 0 || this.ActualWidth > 0 && _vm != null)
            //    _vm.Initialize();
        }

        //void ScrollViewerItems_OnManipulationBoundaryFeedback(object sender, ManipulationBoundaryFeedbackEventArgs e)
        //{
        //    e.Handled = true;
        //}

        public DispatcherTimer TestTimer {  get { return _timer; } }
    }
}
