/// <summary>
/// Ampleon
/// 
/// Define IDebugging interface for RFE 
/// solid state cooking tools
/// 
/// </summary>
namespace Interfaces
{
    public delegate void SetDbCallback(int db);
    /// <summary>
    /// All functions throw ApplicationException on failure
    /// with the error description filled-in
    /// </summary>
    public interface IDebugging
    {
        /// <summary>
        /// I2C Address of 4-channel MCP4728 dac
        /// </summary>
        int Mcp4728Address { get; set; }

        /// <summary>
        /// I2C address of single-channel MCP4726 dac
        /// </summary>
        int Mcp4726Address { get; set; }

        /// <summary>
        /// 4 channel MCP4728 dac volts per lsb
        /// </summary>
        double Mcp4728VoltsPerLsb { get; set; }

        /// <summary>
        /// Single channel MCP4726 dac volts per lsb
        /// </summary>
        double Mcp4726VoltsPerLsb { get; set; }

        /// <summary>
        /// Called when the power changes
        /// arg is q7.8 last db value
        /// </summary>
        //event SetDbCallback SetDbHandler;

        /// <summary>
        /// Initialize hardware
        /// </summary>
        /// <returns></returns>
        int Initialize(string logFile);

        /// <summary>
        /// Shutdown hardware
        /// </summary>
        void Close();

        /// <summary>
        /// Return firmware revision
        /// </summary>
        string FirmwareVersion { get; }

        /// <summary>
        /// Return FPGA revision
        /// If no FPGA hardware, returns an
        /// empty string ("")
        /// </summary>
        string FPGAversion { get; }


        /// <summary>
        /// Set tag data in EEPROM,
        /// string data
        /// </summary>
        /// <param name="name"></param>
        /// <param name="value"></param>
        /// <returns></returns>
        int SetTag(string name, string value);

        /// <summary>
        /// Set tag data in EEPROM, binary data
        /// </summary>
        /// <param name="name"></param>
        /// <param name="value"></param>
        /// <returns></returns>
        int SetTag(string name, byte[] value);

        /// <summary>
        /// Get string tag data
        /// </summary>
        /// <param name="name"></param>
        /// <param name="value"></param>
        /// <returns></returns>
        int GetTag(string name, ref string value);

        /// <summary>
        /// Get binary tag data
        /// </summary>
        /// <param name="name"></param>
        /// <param name="value"></param>
        /// <returns></returns>
        int GetTag(string name, ref byte[] value);

        /// <summary>
        /// Write EEPROM data
        /// </summary>
        /// <param name="offset"></param>
        /// <param name="data"></param>
        /// <returns></returns>
        int WriteEeprom(int offset, byte[] data);

        /// <summary>
        /// Read EEPROM data. Se the size of the byte
        /// array before calling to set the read length.
        /// </summary>
        /// <param name="offset"></param>
        /// <param name="data"></param>
        /// <returns></returns>
        int ReadEeprom(int offset, ref byte[] data);

        int WriteI2C(int bus, int address, byte[] data);

        /// <summary>
        /// Read from I2C device, handles write before read.
        /// </summary>
        /// <param name="channel">0 to 4</param>
        /// <param name="address">device address</param>
        /// <param name="wrbytes">write before read bytes, can be null</param>
        /// <param name="data">data read, length of this array is
        /// the number of bytes read.</param>
        /// <returns>data, status code=0 on success</returns>
        /// <remarks>HID report max bytes is 32, 6 are used for 
        /// status return, so 26 bytes is maximum for USB HID 
        /// cooking tools(prototype M2). Other interfaces such 
        /// as RS422, RS485 will not have this restriction.</remarks>
        int ReadI2C(int channel, int address, byte[] wrbytes, byte[] data);

        int WrRdSPI(int device, ref byte[] data);

        /// <summary>
        /// Run background thread to monitor voltage, temperature, current
        /// </summary>
        bool LoopReadings { get; set; }

        /// <summary>
        /// Delay between readings in monitor loop, milliseconds
        /// </summary>
        int LoopDelayMs { get; set; }
    }
}
