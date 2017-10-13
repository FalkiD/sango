using System;
using System.Windows.Data;

namespace Converters
{
    [ValueConversion(typeof(bool), typeof(string))]
    public class BoolToYesNoConverter : IValueConverter
    {
        public object Convert(object value, Type targetType, object parameter,
                               System.Globalization.CultureInfo culture)
        {
            var state = (bool)value;
            return state ? "Yes" : "No";
        }

        public object ConvertBack(object value, Type targetType, object parameter,
              System.Globalization.CultureInfo culture)
        {
            return null;
        }
    }
}
