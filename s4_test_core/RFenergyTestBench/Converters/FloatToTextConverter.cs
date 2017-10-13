using System;
using System.Windows.Data;

namespace Converters
{
	[ValueConversion( typeof( float ), typeof( string ) )]
	public class FloatToTextConverter : IValueConverter
	{
		public object Convert(object value, Type targetType, object parameter, System.Globalization.CultureInfo culture)
		{
			return value.ToString();
		}

		public object ConvertBack(object value, Type targetType, object parameter, System.Globalization.CultureInfo culture)
		{
			float f;
			if (value is string && float.TryParse(value as string, out f))
			{
				return f;
			}
			return 0f;
		}
	}
}
