using System.Windows;
using System.Windows.Input;
using RFenergyUI.ViewModels;

namespace RFenergyUI.Views
{
    /// <summary>
    /// Interaction logic for AboutView.xaml
    /// </summary>
    public partial class AboutView : Window
    {
        AboutViewModel _vm;

        public AboutView()
        {
            _vm = new AboutViewModel(this);
            DataContext = _vm;
            InitializeComponent();
            this.PreviewKeyDown += new KeyEventHandler(CloseOnEscape);
        }

        void CloseOnEscape(object sender, KeyEventArgs e)
        {
            if (e.Key == Key.Escape || e.Key == Key.Enter)
                Close();
        }
    }
}
