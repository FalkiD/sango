﻿using System;
using System.Windows;
using System.Windows.Data;

namespace Converters
{
	[ValueConversion(typeof(bool), typeof(Visibility))]
	public class BoolToVisibilityConverter : IValueConverter
	{
		public object Convert(object value, Type targetType, object parameter,
							   System.Globalization.CultureInfo culture)
		{
			if ((bool) value)
				return Visibility.Visible;

			return Visibility.Collapsed;
		}

		public object ConvertBack(object value, Type targetType, object parameter,
			  System.Globalization.CultureInfo culture)
		{
			return null;
		}
	}
}




