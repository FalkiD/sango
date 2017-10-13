/*
    Main window ViewModel.
    Top level items
*/
using System;
using System.Configuration;
using System.Diagnostics;
using System.IO;
using System.Windows.Media;
using Interfaces;
using M2TestModule;
using MmcTestModule;
using S4TestModule;
using ReactiveUI;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using ExternalPowerMeter;

namespace RFenergyUI.ViewModels
{
    public class MainViewModel : ReactiveObject
    {
        public static int VersionMajor = 0;
        public static int VersionMinor = 2;

        // public statics for everyone
        public static IDebugging IDbg { get; set; }
        public static IErrors IErr { get; set; }
        public static ICommands ICmd { get; set; }
        public static IOpcodes IOpcodes { get; set; }
        public static ExternalMeter IMeter { get; set; }

        public static void MsgAppendLines(List<string> results)
        { ThisPtr.AppendLines(results); }
        public static void MsgAppendLine(string format, params object[] args)
        { ThisPtr.AppendLine(format, args); }
        public static string MainLogFile
        { get { return ThisPtr.LogFile; } }

        public static bool ToggleDBgTabVisibility()
        {
            ThisPtr.ShowDebugTab = ThisPtr.ShowDebugTab ? false : true;
            return ThisPtr.ShowDebugTab;
        }

        // Kludge to update one ViewModel from another. Need IOC from Splat...
        public static CalViewModel CalPanel { get; set; }
        public static TestViewModel TestPanel { get; set; }
        public static RfeDebugViewModel DebugPanel { get; set; }

        public static string SelectedSystemName
        { get { return ThisPtr.SelectedSystem.SystemName; } }

        // internal properties
        static MainViewModel ThisPtr { get; set; }
        string LogFile { get; set; }
        MainWindow MainView { get; set; }

        // ctor
        public MainViewModel(MainWindow view)
        {
            ThisPtr = this;
            MainView = view;
            LogFile = Environment.GetFolderPath(Environment.SpecialFolder.CommonDocuments) + "\\" + "\\RfeMonitorLog.txt";
            RfModules = new ObservableCollection<SysList>();
            LogData = new ObservableCollection<string>();
            string packUri = "pack://application:,,,/RfenergyUi;component/Resources/Images/m2icon.png";
            var image = new ImageSourceConverter().ConvertFromString(packUri) as ImageSource;
            RfModules.Add(new SysList { SystemName = "M2", SystemIcon = image });
            packUri = "pack://application:,,,/RfenergyUi;component/Resources/Images/s4icon.png";
            image = new ImageSourceConverter().ConvertFromString(packUri) as ImageSource;
            RfModules.Add(new SysList { SystemName = "S4", SystemIcon = image });
            //packUri = "pack://application:,,,/RfenergyUi;component/Resources/Images/x7icon.png";
            //image = new ImageSourceConverter().ConvertFromString(packUri) as ImageSource;
            //RfModules.Add(new SysList { SystemName = "X7A", SystemIcon = image });
            //packUri = "pack://application:,,,/RfenergyUi;component/Resources/Images/xilinx-fpgas.jpg";
            //image = new ImageSourceConverter().ConvertFromString(packUri) as ImageSource;
            //RfModules.Add(new SysList { SystemName = "MMC/FPGA", SystemIcon = image });

            ShowDebugTab = ConfigurationManager.AppSettings["mode"] == "factory" ? true : false;

            SelectedSystem = RfModules[1];
        }

        // Properties
        public ObservableCollection<SysList> RfModules { get; set; }
        //public int SelectedItem { get; set; }
        public SysList SelectedSystem { get; set; }

        public ObservableCollection<string> LogData { get; set; }
        public string SelectedLogLine { get; set; }
        public int LogSelectedIndex { get; set; }
        public bool ShowDebugTab { get; set; }

        // public funcs

        public void SystemSelectionChanged()
        {
            StartupHardware();
        }

        public void StartupHardware()
        {
            try
            {
                if (SelectedSystem == null)
                    return;

                this.Close();
                if (SelectedSystem.SystemName == "M2")
                {
                    M2Module mod;
                    mod = new M2Module();
                    IDbg = (IDebugging)mod;
                    IErr = (IErrors)mod;
                    ICmd = (ICommands)mod;

                    IMeter = new ExternalMeter();
                    IMeter.ShowMessage += new MessageCallback(ShowMessage);
                    //IMeter.Startup();
                }
                else if (SelectedSystem.SystemName == "S4")
                {
                    S4Module mod;
                    mod = new S4Module();
                    IDbg = (IDebugging)mod;
                    IErr = (IErrors)mod;
                    ICmd = (ICommands)mod;
                    ICmd.ShowMessage += new MessageCallback(ShowMessage);
                    //IOpcodes = (IOpcodes)mod;
                }
                else if (SelectedSystem.SystemName == "MMC/FPGA")
                {
                    MmcModule mod;
                    mod = new MmcModule();
                    IDbg = (IDebugging)mod;
                    IErr = (IErrors)mod;
                    ICmd = (ICommands)mod;
                    IOpcodes = (IOpcodes)mod;
                }
                //IDbg.Initialize(LogFile);
            }
            catch (Exception ex)
            {
                AppendLine(string.Format("Error writing report:{0}", ex.Message));
            }
        }

        public void Close()
        {
            // View calls when app closing or system selection changes
            if(IDbg != null)
                IDbg.Close();
        }

        void ShowMessage(string msg)
        {
            AppendLine(msg);
        }

        public void AppendLines(List<string> results)
        {
            foreach (var line in results)
                AppendLine(line);
        }

        public static string Timestamp
        {
            get
            {
                var now = DateTime.Now;
                return string.Format("{0:d02}_{1:d02}_{2:d02}_{3:d02}_{4:d02}_{5:d02}.{6:d03}:",
                                                now.Month, now.Day, now.Year,
                                                now.Hour, now.Minute, now.Second,
                                                now.Millisecond);
            }
        }

        public static string TimestampShort
        {
            get
            {
                var now = DateTime.Now;
                return string.Format("{0:d02}_{1:d02}_{2:d02}_{3:d02}_{4:d02}_{5:d02}:",
                                                now.Month, now.Day, now.Year,
                                                now.Hour, now.Minute, now.Second);
            }
        }

        public void AppendLine(string format, params object[] args)
        {
            string line = string.Format(format, args);
            line = Timestamp + line;
            ObservableCollection<string> newList = LogData;
            if (LogData.Count >= 1000)
            {
                // Replace list with new smaller list
                newList = new ObservableCollection<string>();
                for (int k = LogData.Count - 500; k < LogData.Count; ++k)
                {
                    newList.Add(LogData[k]);
                }
                newList.Add(line);
                LogData = newList;
            }
            else LogData.Add(line);


            StreamWriter fLog = null;
            try
            {
                fLog = new StreamWriter(LogFile, true);
                if (fLog != null)
                {
                    if (!line.EndsWith("\n"))
                        line += "\r\n";
                    fLog.Write(line);
                    fLog.Close();
                }
            }
            catch (Exception ex)
            {
                // Can't write to the file, last resort...
                Debug.WriteLine("AppendLine() exception:{0}", ex.Message);
            }
            finally
            {
                if (fLog != null) fLog.Close();
            }
        }

    }

    /// <summary>
    /// A list of system names & icons to be displayed
    /// on the left main panel. User will choose system
    /// type.
    /// </summary>
    public class SysList
    {
        public string SystemName { get; set; }
        public ImageSource SystemIcon { get; set; }
    }

}
