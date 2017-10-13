
using System.Diagnostics;
using System.Windows;
using System.Linq;
using RFenergyUI.Views;

namespace RFenergyUI
{
    /// <summary>
    /// Interaction logic for App.xaml
    /// </summary>
    public partial class App : Application
    {
        const int MINIMUM_SPLASH_TIME = 2000;

        protected override void OnStartup(StartupEventArgs e)
        {
            var proc = Process.GetCurrentProcess();
            var count = Process.GetProcesses().Count(p => p.ProcessName == proc.ProcessName);
            if (count > 1)
            {
                const string abc = "*****************************************************************";
                const string err = "An instance of M2host.exe is already running, exiting.";
                Debug.Indent();
                Debug.WriteLine(abc);
                Debug.WriteLine(err);
                Debug.WriteLine(abc);
                Debug.Unindent();
                //Logger.Warn(err);
                Current.Shutdown();
                return;
            }
            //Logger.Info("RFenergyUI.exe starting.");

            AboutView splash = new AboutView();
            splash.Show();
            // Step 2 - Start a stop watch  
            Stopwatch timer = new Stopwatch();
            timer.Start();

            // Step 3 - Load your windows but don't show it yet  
            base.OnStartup(e);
            var mainWindow = new MainWindow();
            MainWindow = mainWindow;
            timer.Stop();

            int remainingTimeToShowSplash = MINIMUM_SPLASH_TIME - (int)timer.ElapsedMilliseconds;
            if (remainingTimeToShowSplash > 0)
                System.Threading.Thread.Sleep(remainingTimeToShowSplash);
            splash.Close();

            //var startupVm = RxApp.GetService<StartupViewModel>();
            //Bootstrapper.Router.Navigate.Execute(startupVm);

            mainWindow.WindowStyle = WindowStyle.ThreeDBorderWindow;
            mainWindow.ResizeMode = ResizeMode.CanResizeWithGrip;
            mainWindow.WindowStartupLocation = WindowStartupLocation.CenterScreen;
            mainWindow.SourceInitialized += (s, a) => mainWindow.WindowState = WindowState.Normal; //.Maximized;

            mainWindow.Show();
        }

        //protected override void OnExit(ExitEventArgs e)
        //{ 
        //    AppBootstrapper.Kernel.Dispose();   // Close Singletons including hardware drivers
        //    Logger.Info("SiteControllerWPF.exe OnExit().");
        //}
    }
}
