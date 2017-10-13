using System.Collections.Generic;

namespace Interfaces
{
    /// <summary>
    /// PA status info
    /// </summary>
    public struct MonitorPa
    {
        public double Voltage;
        public double Current;
        public double Temperature;
        public double IDrv;
        public double Forward;
        public double Reflected;
        public string ErrorMessage;
    }

    /// <summary>
    /// General command interface for 
    /// Ampleon RF Energy  tools
    /// </summary>
    /// <remarks>All methods return a status code integer</remaorks>
    public interface ICommands
    {
        event MessageCallback ShowMessage;

        /// <summary>
        /// Run byte array command, no response
        /// </summary>
        /// <param name="command"></param>
        /// <returns></returns>
        int RunCmd(byte[] command);

        /// <summary>
        /// Run string command, no response
        /// </summary>
        /// <param name="command"></param>
        /// <returns></returns>
        int RunCmd(string command);

        /// <summary>
        /// Run byte command, return byte array response
        /// </summary>
        /// <param name="command"></param>
        /// <param name="response"></param>
        /// <returns></returns>
        int RunCmd(byte[] command, ref byte[] response);

        /// <summary>
        /// Run string command, return string response
        /// </summary>
        /// <param name="command"></param>
        /// <param name="response"></param>
        /// <returns></returns>
        int RunCmd(string command, ref string response);

        /// <summary>
        /// The formatted result(s) from the last thing executed
        /// </summary>
        List<string> Results { get; set; }

        /// <summary>
        /// Set frequency in hertz
        /// </summary>
        /// <param name="hertz"></param>
        /// <returns>status code</returns>
        int SetFrequency(double hertz);
        int GetFrequency(ref double hertz);

        /// <summary>
        /// Set power in dBm
        /// </summary>
        /// <param name="dbm"></param>
        /// <returns>status code</returns>
        int SetPower(double dbm);
        int GetPower(ref double dbm);

        /// <summary>
        /// Read last programmed power level in dB, a value
        /// referenced to a low-level power that's 
        /// hardware-specific.
        /// </summary>
        /// <param name="db"></param>
        /// <returns></returns>
        /// <remarks>Programming power in dB allows 
        /// linear interpolation. Value is converted to 
        /// lsb's at a low level immediately prior to
        /// writing hardware.</remarks>
        int LastProgrammedDb(ref double db);

        /// <summary>
        /// Setup PWM, On/Off, etc
        /// </summary>
        /// <param name="duty"></param>
        /// <param name="rateHz"></param>
        /// <param name="on"></param>
        /// <returns></returns>
        int SetPwm(int duty, int rateHz, bool on, bool external);

        /// <summary>
        /// Read coupler power
        /// </summary>
        /// <param name="forward">Coupler forward power</param>
        /// <param name="reflected">Coupler reflected power</param>
        /// <returns></returns>
        int CouplerPower(int type, ref double forward, ref double reflected);

        /// <summary>
        /// Read ZMon power, results in dBm
        /// </summary>
        /// <param name="forward"></param>
        /// <param name="reflected"></param>
        /// <returns></returns>
        int ZMonPower(ref double forward, ref double reflected);

        /// <summary>
        /// Read device status
        /// </summary>
        string Status { get; }

        /// <summary>
        /// Calibration flag
        /// </summary>
        bool CalibrationOn { get; set; }

        /// <summary>
        /// Returns PA channels supported by the hardware
        /// </summary>
        int PaChannels { get; }

        /// <summary>
        /// Return the present settings of the hardware
        /// </summary>
        /// <param name="settings"></param>
        /// <returns></returns>
        int GetState(ref RfSettings settings);

        /// <summary>
        /// Return PA status info
        /// </summary>
        /// <param name="status">Coupler data, raw, 
        ///with offset removed, or corrected dBm. See
        ///M2 firmware reference for values.</param>
        /// <param name="results">Readings</param>
        /// <returns></returns>
        int PaStatus(int couplerMode, ref MonitorPa[] results);

        /// <summary>
        /// Set the high resolution frequency mode state, ON or OFF
        /// </summary>
        /// <param name="frequencyHiresMode">true=ON, false=OFF</param>
        /// <returns></returns>
        int HiresMode(bool frequencyHiresMode);

        /// <summary>
        /// Duty Cycle compensation must be OFF to calibrate.
        /// Normally ON
        /// </summary>
        /// <param name="enable"></param>
        /// <returns></returns>
        int DutyCycleCompensation(bool enable);

        /// <summary>
        /// Control temperature compensation.
        /// </summary>
        /// <param name="mode">0=ambient
        /// 1=open loop control(algorithmic)
        /// 2=closed loop control using coupler</param>
        /// <returns></returns>
        int TemperatureCompensation(int mode);
    }
}
