
using System;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
using RFenergyUI.Views;
using RFenergyUI.ViewModels;
using System.Diagnostics;

namespace RFenergyUI
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        MainViewModel   _vm;
        DispatcherTimer _dispatcherTimer;

        public MainWindow()
        {
            _vm = new MainViewModel(this);
            this.DataContext = _vm;     // Bindings
            InitializeComponent();
        }

        private void Window_Loaded(object sender, RoutedEventArgs e)
        {
            try
            {
                _vm.StartupHardware();

                // Setup a timer for processing data
                _dispatcherTimer = new DispatcherTimer();
                _dispatcherTimer.Tick += new EventHandler(DispatcherTimer_Tick);
                _dispatcherTimer.Interval = new TimeSpan(0, 0, 0, 0, 750);
                //_dispatcherTimer.Start();
            }
            catch (Exception ex)
            {
                if (_vm != null)
                    _vm.AppendLine(string.Format("OnLoad exception:{0}", ex.Message));
                else
                    Debug.WriteLine(string.Format("OnLoad exception:{0}", ex.Message));
            }
        }

        void Window_Closing(object sender, System.ComponentModel.CancelEventArgs e)
        {
            if (_vm != null)
                _vm.Close();
            else
                Debug.WriteLine("Window_Closing:Can't close hardware, ViewModel is null");
        }

        void AppExit_Click(object sender, RoutedEventArgs e)
        {
            Application.Current.Shutdown();
        }

        private void DispatcherTimer_Tick(object sender, EventArgs e)
        {
            try
            {
                //_vm.AppendLine("Testing...");
            }
            catch (Exception ex)
            {
                _vm.AppendLine(string.Format("OnLoad exception:{0}", ex.Message));
            }
        }

        public void SetTimer(int milliseconds)
        {
            _dispatcherTimer.Stop();
            _dispatcherTimer.Interval = new TimeSpan(0, 0, 0, 0, milliseconds);
            _dispatcherTimer.Start();
        }

        public void StopTimer()
        {
            _dispatcherTimer.Stop();
        }

        public void StartTimer()
        {
            _dispatcherTimer.Start();
        }

        private void ListBox_SelectionChanged(object sender, System.Windows.Controls.SelectionChangedEventArgs e)
        {
            if (_vm != null)
                _vm.SystemSelectionChanged();
        }

        private void About_Click(object sender, RoutedEventArgs e)
        {
            AboutView about = new AboutView();
            about.Show();
        }

        private void ListBox_PreviewMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
        {

            if ((Keyboard.IsKeyDown(Key.LeftCtrl) || Keyboard.IsKeyDown(Key.RightCtrl)) &&
                (Keyboard.IsKeyDown(Key.LeftShift) || Keyboard.IsKeyDown(Key.RightShift)))
            {
                // Toggle Visibility of Debugging tab
                MainViewModel.ToggleDBgTabVisibility();
            }
        }
    }
}
