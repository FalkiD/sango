using System;
using System.Windows.Data;
using RFenergyUI.ViewModels;

namespace Converters
{
    [ValueConversion(typeof(int), typeof(string))]
    public class IntTextConverter : IValueConverter
    {
        public object Convert(object value, Type targetType, object parameter, System.Globalization.CultureInfo culture)
        {
            return value.ToString();
        }

        public object ConvertBack(object value, Type targetType, object parameter, System.Globalization.CultureInfo culture)
        {
            if (value is string)
            {
                try
                {
                    if (((string)value).Length == 0)
                        value = "0";
                    return System.Convert.ToInt32(value as string);
                }
                catch (Exception ex)
                {
                    MainViewModel.MsgAppendLine("IntTextConverter.ConvertBack() exception:{0}", ex.Message);
                }
            }
            return 0;
        }
    }
}