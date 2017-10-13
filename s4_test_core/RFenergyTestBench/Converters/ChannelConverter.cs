using System;
using System.Windows.Data;

namespace Converters
{
	[ValueConversion( typeof(int), typeof( string ) )]
	public class ChannelConverter : IValueConverter
	{
		public object Convert(object value, Type targetType, object parameter, System.Globalization.CultureInfo culture)
		{
			return string.Format("Channel {0}", System.Convert.ToString(value));
		}

		public object ConvertBack(object value, Type targetType, object parameter, System.Globalization.CultureInfo culture)
		{
			return 0;
		}
	}
}
