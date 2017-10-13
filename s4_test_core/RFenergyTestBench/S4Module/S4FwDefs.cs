namespace S4TestModule
{
    public class S4FwDefs
    {
        public const int CHANNELS = 1;

        /// <summary>
        /// ///Bogus, all from M2*******
        /// </summary>


        public const int POWER_OUT = 1;
        public const int VI_CHANNEL1 = 2;
        public const int VI_CHANNEl2 = 3;
        public const int VI_CHANNEL3 = 4;
        public const int VI_CHANNEL4 = 5;
        public const int SYN = 6;
        public const int ZMON_FWD = 7;
        public const int ZMON_REFL = 8;
        public const int IQDAC = 9;

        /// <summary>
        /// M2 error codes
        /// </summary>
        public const int ERR_CMD_NO_MEMORY = 1;		// Can't create Command struct to add to QUEUE
        public const int ERR_INVALID_CMD = 2;
        public const int ERR_INVALID_ARGS = 3;
        public const int ERR_INVALID_I2C_BUS = 4;		// 0-5 supported
        public const int ERR_CMD_QUEUE_FULL = 5;		// Can't add command to QUEUE
        public const int ERR_CMD_QUEUE_NULL = 6;		// Command queue was not created
        public const int ERR_CMD_QUEUE_RD_TIMEOUT = 7;
        public const int ERR_QUEUE_FULL = 8;		// Can't add entry to QUEUE
        public const int ERR_QUEUE_NULL = 9;		// General queue was not created
        public const int ERR_QUEUE_RD_TIMEOUT = 10;
        public const int ERR_QUEUE_NOT_CREATED = 11;
        public const int ERR_RESPONSE_QUEUE_EMPTY = 12;
        public const int ERR_INCOMPLETE_I2C_WRITE = 13;
        public const int ERR_INCOMPLETE_I2C_READ = 14;
        public const int ERR_SPI_IO_ERROR = 15;
        public const int ERR_READ_SIZE_TOO_LARGE = 16;	// HID input report size(64) minus 6 bytes for status & 5 bytes echo'd
        public const int ERR_INVALID_SPI_DEVICE = 17;
        public const int ERR_I2C_NACK = 18;
        public const int ERR_I2C_ARBLOST = 19;
        public const int ERR_I2C_BUSERR = 20;
        public const int ERR_I2C_BUSY = 21;
        public const int ERR_I2C_SLAVENAK = 22;
        public const int ERR_I2C_UNKNOWN = 23;
        public const int ERR_CFG_ADC = 24;	// Error reading back ADS1015 ADC config register
        public const int ERR_INVALID_PWM_DUTY_CYCLE = 25;
        public const int ERR_INVALID_PWM_RATE = 26;
        public const int ERR_WRITING_CALDATA = 27;
        public const int ERR_READING_CALDATA = 28;
        public const int ERR_TEMPADC_NOTREADY = 29;
        public const int ERR_TEMPADC_INVALID = 30;
        public const int ERR_INVALID_RF_CHANNEL = 31;
        public const int ERR_CALDATA_INVALID = 32;
        public const int ERR_LOW_POWER_NOT_SUPPORTED = 33;
        public const int ERR_CALDATA_TOO_LARGE = 34;
        public const int ERR_INVALID_IQOFFSET = 35;
        public const int ERR_NO_PLL_LOCK = 36;
        public const int ERR_CMD_TIMEOUT = 37;
        public const int ERR_PANEL_NOT_FOUND = 38;
        public const int ERR_TOO_MANY_POPUPS = 39;
        public const int ERR_CREATING_PANEL = 40;
        public const int ERR_LCD_CMD_BUSY = 41;
        public const int ERR_DRAW_FOCUS = 42;
        public const int ERR_DRAW_PANEL = 43;
        public const int ERR_LCD_UNKNOWN_KEY = 44;

        public const int ERR_TAG_NOT_FOUND = 45;
        public const int ERR_TAG_TOO_LONG = 46;
        public const int ERR_TAG_NO_EQUALS = 47;
        public const int ERR_TAG_NAME_LEN = 48;
        public const int ERR_TAG_VAL_LEN = 49;
        public const int ERR_NO_TAG_DELIMITER = 50;
        public const int ERR_TAG_GENERAL = 51;

        public const int ERR_INVALID_PNL_TYPE = 60;
        public const int ERR_CHECKBOX_SETUP = 61;
        public const int ERR_NO_MEMORY = 62;
        public const int ERR_I2C_ZEROBYTES = 63;
        public const int ERR_SPI_ZEROBYTES = 64;

        public const int ERR_UNKNOWN = 100;
    }
}
