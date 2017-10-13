namespace M2TestModule
{
    public class M2Cmd
    {
        public const byte I2C_WR = 0x64;
        public const byte I2C_RD = 0x65;
        public const byte SPI = 0x66;
        public const byte RF_CTRL = 0x67;
        public const byte RF_STATUS = 0x68;
        public const byte RF_POWER = 0x69;
        public const byte FREQ = 0x6A;
        public const byte POWER = 0x6B;
        public const byte PHASE = 0x6C;
        public const byte PWM = 0x6D;
        public const byte SYNC = 0x6E;
        public const byte CALWR = 0x6F;
        public const byte CALRD = 0x70;
        public const byte CAL_MTR = 0x71;
        public const byte VERSION = 0x72;
        public const byte CLR_STATUS = 0x73;
        public const byte CAL_PWR = 0x74;
        public const byte COMP_TEMP = 0x75;
        public const byte CAL_SAVE_PWRCAL = 0x76;
        public const byte SET_TAG = 0x77;
        public const byte GET_TAG = 0x78;
        public const byte IDRV = 0x79;
        public const byte PWRCAL = 0x7a;
        public const byte LASTDB = 0x7b;

        public const byte GPIO_WR = 0xA0;
        public const byte CAL_SAVE = 0xA1;
        public const byte I2CEN_WR = 0xA2;
        public const byte I2CEN_RD = 0xA3;
        public const byte ENABLE_WR = 0xA4;
        public const byte ENABLE_RD = 0xA5;
        public const byte RSP_QUEUE_SIZE = 0xA6;
        public const byte DEBUGGING = 0xA7;
        public const byte BAUDRATE = 0xA8;
        public const byte COMP_DC = 0xA9;
        public const byte TICK_COUNT = 0xAA;
        public const byte FAULT_LED = 0xAB;
        public const byte DEMO_MODE = 0xAC;
        public const byte CLEAR_TAGS = 0xAD;
        public const byte RD_EEPROM = 0xAE;
        public const byte WR_EEPROM = 0xAF;

        // USB M2 is a HID interface with 32 byte report size
        public const int BYTES_PER_READ = 16;

        public const byte PWR_DBM = 1;
        public const byte PWR_ADC = 2;
        public const byte PWR_RAW = 3;

        public const int MTR_UPDATE_INUSE = 0x01;
        public const int MTR_UPDATE_EEPROM = 0x02;
        public const int MTR_CAL_DATA = 11; // 10 bytes of data plus flags byte
    }
}
