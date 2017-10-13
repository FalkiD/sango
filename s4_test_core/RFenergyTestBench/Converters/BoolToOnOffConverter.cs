using System;
using System.Windows.Data;

namespace Converters
{
    [ValueConversion(typeof(bool), typeof(string))]
    public class BoolToOnOffConverter : IValueConverter
    {
        public object Convert(object value, Type targetType, object parameter,
                               System.Globalization.CultureInfo culture)
        {
            var state = (bool)value;
            if ((string) parameter == "Logging")
            {
                return state ? "Logging is On" : "Logging is Off";
            }
			if ((string)parameter == "ColdFluid")
			{
				return state ? "Cold Fluid is On" : "Cold Fluid is Off";
			}
			if ((string)parameter == "DrawDown")
			{
				return state ? "Draw Down is On" : "Draw Down is Off";
			}
            return state ? "On" : "Off";
        }

        public object ConvertBack(object value, Type targetType, object parameter,
              System.Globalization.CultureInfo culture)
        {
            return null;
        }
    }
}