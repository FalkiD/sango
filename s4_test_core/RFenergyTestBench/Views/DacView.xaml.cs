using System.Windows.Controls;

namespace RFenergyUI.Views
{
    /// <summary>
    /// Interaction logic for DacView.xaml
    /// </summary>
    public partial class DacView : UserControl
    {
        public DacView()
        {
            if (System.ComponentModel.DesignerProperties.GetIsInDesignMode(this))
                return;

            InitializeComponent();
        }

        /// <summary>
        /// Gets or sets the Title which is being displayed
        /// </summary>
        //public string Title
        //{
        //    get { return (string)GetValue(ValueProperty); }
        //    set { SetValue(ValueProperty, value); }
        //}

        ///// <summary>
        ///// Identified the Label dependency property
        ///// </summary>
        //public static readonly DependencyProperty ValueProperty =
        //    DependencyProperty.Register("Title", typeof(string),
        //                typeof(DacView), new PropertyMetadata(null));
    }
}
