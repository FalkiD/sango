using System;
using System.Windows.Data;
using RFenergyUI.ViewModels;

namespace Converters
{
    [ValueConversion(typeof(int), typeof(string))]
    public class HexTextConverter : IValueConverter
    {
        public object Convert(object value, Type targetType, object parameter, System.Globalization.CultureInfo culture)
        {
            int tmp = System.Convert.ToInt32(value);
            return string.Format("{0:x03}", tmp);
        }

        public object ConvertBack(object value, Type targetType, object parameter, System.Globalization.CultureInfo culture)
        {
            if (value is string)
            {
                try
                {
                    uint tmp = System.Convert.ToUInt32(value as string, 16);
                    return tmp & 0xfff;

                }
                catch(Exception ex)
                {
                    MainViewModel.MsgAppendLine("HexTextConverter.ConvertBack() exception:{0}", ex.Message);
                }
            }
            return 0;
        }
    }
}
