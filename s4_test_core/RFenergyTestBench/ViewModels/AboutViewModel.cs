using System;
using System.Reflection;
using RFenergyUI.Views;

namespace RFenergyUI.ViewModels
{
    public class AboutViewModel
    {
        AboutView _view;

        public AboutViewModel(AboutView view)
        {
            _view = view;
        }

        public string Version
        {
            get
            {
                Version ver = Assembly.GetExecutingAssembly().GetName().Version;
                return string.Format("{0}.{1}", ver.Major, ver.Minor);
            }
        }
    }
}
