using System;
using System.Windows.Data;

namespace Converters
{
    //for the vacuum breaker view
    [ValueConversion(typeof(bool), typeof(string))]
    public class BoolToOpenClosedConverter : IValueConverter
    {
        public object Convert(object value, Type targetType, object parameter,
                               System.Globalization.CultureInfo culture)
        {
            var state = (bool)value;
            return state ? "Open" : "Closed";
        }

        public object ConvertBack(object value, Type targetType, object parameter,
              System.Globalization.CultureInfo culture)
        {
            return null;
        }
    }
}
