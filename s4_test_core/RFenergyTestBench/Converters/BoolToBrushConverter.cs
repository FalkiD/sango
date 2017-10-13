using System;
using System.Windows.Data;
using System.Windows.Media;

namespace Converters
{
	[ValueConversion( typeof( bool ), typeof( Brush ) )]
	public class BoolToBrushConverter : IValueConverter
	{
		public object Convert( object value, Type targetType, object parameter,
							   System.Globalization.CultureInfo culture )
		{
			return (bool)value ? new SolidColorBrush( Color.FromArgb( 0, 0, 0, 255 ) ) : new SolidColorBrush( Color.FromArgb( 0, 150, 255, 0 ) );
		}

		public object ConvertBack( object value, Type targetType, object parameter,
			  System.Globalization.CultureInfo culture )
		{
			return null;
		}
	}
}