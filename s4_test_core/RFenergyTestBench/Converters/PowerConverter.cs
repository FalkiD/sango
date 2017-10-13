using System;
using System.Windows.Data;

namespace Converters
{
    [ValueConversion(typeof(double), typeof(string))]
    public class PowerConverter : IValueConverter
    {
        public object Convert(object value, Type targetType, object parameter, System.Globalization.CultureInfo culture)
        {
            double tmp = System.Convert.ToDouble(value);
            return string.Format("{0:f1}", tmp);
        }

        public object ConvertBack(object value, Type targetType, object parameter, System.Globalization.CultureInfo culture)
        {
            double d;
            if (value is string && double.TryParse(value as string, out d))
            {
                return d;
            }
            return 0d;
        }
    }

    [ValueConversion(typeof(double), typeof(string))]
    public class PowerCalConverter : IValueConverter
    {
        public object Convert(object value, Type targetType, object parameter, System.Globalization.CultureInfo culture)
        {
            double tmp = System.Convert.ToDouble(value);
            return string.Format("{0:f3}", tmp);
        }

        public object ConvertBack(object value, Type targetType, object parameter, System.Globalization.CultureInfo culture)
        {
            double d;
            if (value is string && double.TryParse(value as string, out d))
            {
                return d;
            }
            return 0d;
        }
    }

}
