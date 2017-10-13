using System;
using System.Net;
using System.Net.Sockets;
using System.Text;

namespace S4TestModule
{
    enum ConnectionStatus
    {
        Disconnected,
        Connecting,
        Disconnecting,
        Connected
    };

    class IoThreadStatus
    {
        int status { get; set; }
    }


    public class S4Hardware
    {
        // Publics

        // Private fields

        // S4 default ip address
        IPAddress           _s4Address   = new IPAddress(new byte[] { 192, 168, 10, 3 });
        IPAddress           _myAddress   = new IPAddress(new byte[] { 192, 168, 10, 10 });
        IPAddress           _subnetMask  = new IPAddress(new byte[] { 255, 255, 255, 0 });
        ConnectionStatus    _connectionStatus;
        IPEndPoint          _endPoint;
        string              _response;
        Socket              _socket = null;

        string logFile { get; set; }

        // Milliseconds to wait for the M2 MCU to execute a command
        int mcuExecuteTimeout { get; set; }

        /// <summary>
        /// Open hardware.
        /// </summary>
        /// <param name="logFile"></param>
        /// <returns>0 if Ok, 100 on failure to open device</returns>
        public int StartupHardware(string logFile)
        {
            try
            {
                mcuExecuteTimeout = 500;    // half a second for now...
                this.logFile = logFile;
                Connect();
                if (_connectionStatus == ConnectionStatus.Connected)
                {
                    S4Module.WriteMessage("Sango S4 plasma ignition source connected.");
                    string[] lines = _response.Split(new char[] { '\n' });
                    foreach(string line in lines)
                    {
                        string next = line;
                        if (next.Length == 0)
                            continue;
                        if (next.EndsWith("\r"))
                            next = next.Substring(0, next.Length - 1);
                        S4Module.WriteMessage(next);
                    }
                    return 0;
                }
                else
                {
                    S4Module.WriteMessage("**Error opening S4 socket");
                    return 100;
                }
            }
            catch (Exception ex)
            {
                S4Module.WriteMessage(string.Format("Error opening S4 socket:{0}", ex.Message));
                return 100;
            }
        }

        public void Close()
        {
            try
            {
                Disconnect();
            }
            catch (Exception ex)
            {
                S4Module.WriteMessage(string.Format("Exception closing S4 socket:{0}", ex.Message));
            }
        }

        // <returns>true on success, false on error</returns>
        public bool WriteCommand(string command)
        {
            try
            {
                return Send(command, _socket) >= command.Length ? true : false;
            }
            catch (Exception ex)
            {
                S4Module.WriteMessage(string.Format("Error writing command to S4:{0}",
                                                         ex.Message));
                return false;
            }
        }

        /*
         * Read the response.
         * Returns data in response array.
         * Returns status byte, 0=Success
         */
        public int ReadResponse(ref string response)
        {
            try
            {
                response = "";
                return Receive(_socket, ref response);
            }
            catch (Exception ex)
            {
                S4Module.WriteMessage(string.Format("**ERROR reading from S4:{0}**",
                                                    ex.Message));
            }
            return response.Length > 0 ? 0 : 100;
        }

        /// <summary>
        /// Returns 0 on success, error code on failure
        /// </summary>
        /// <param name="command"></param>
        /// <param name="response"></param>
        /// <returns></returns>
        public int ExecuteCommand(string command, ref string response)
        {
            bool status = WriteCommand(command);
            if (status)
            {
                System.Threading.Thread.Sleep(100);
                return ReadResponse(ref response) > 0 ? 0 : 100;
            }
            else return 100;
        }

        public string ErrorDescription(int errorCode)
        {
            switch (errorCode)
            {
                case 0:
                    return "Success";
                case S4FwDefs.ERR_CMD_NO_MEMORY:
                    return "[1] Error allocating memory for Command";
                case S4FwDefs.ERR_INVALID_CMD:
                    return "[2] Error, invalid command";
                case S4FwDefs.ERR_INVALID_ARGS:
                    return "[3] Error, invalid command argument(s)";
                case S4FwDefs.ERR_INVALID_I2C_BUS:
                    return "[4] Error, invalid I2C enable, 0 to 5 are valid";
                case S4FwDefs.ERR_CMD_QUEUE_FULL:
                    return "[5] Error, command queue is full";
                case S4FwDefs.ERR_CMD_QUEUE_NULL:
                    return "[6] Error, command queue was not created";
                case S4FwDefs.ERR_CMD_QUEUE_RD_TIMEOUT:
                    return "[7] Error, timeout waiting for command queue";
                case S4FwDefs.ERR_QUEUE_FULL:
                    return "[8] Error, basic queue full";
                case S4FwDefs.ERR_QUEUE_NULL:
                    return "[9] Error, basic queue not created";
                case S4FwDefs.ERR_QUEUE_RD_TIMEOUT:
                    return "[10] Error, basic queue timeout";
                case S4FwDefs.ERR_QUEUE_NOT_CREATED:
                    return "[11] Error, response queue not created";
                case S4FwDefs.ERR_RESPONSE_QUEUE_EMPTY:
                    return "[12] Error, response queue is empty";
                case S4FwDefs.ERR_INCOMPLETE_I2C_WRITE:
                    return "[13] Error, incomplete I2C write";
                case S4FwDefs.ERR_INCOMPLETE_I2C_READ:
                    return "[14] Error, incomplete I2C read";
                case S4FwDefs.ERR_SPI_IO_ERROR:
                    return "[15] Error, SPI IO problem";
                case S4FwDefs.ERR_READ_SIZE_TOO_LARGE:
                    return "[15] Error, HID read size too large(>32 bytes total)";
                case S4FwDefs.ERR_INVALID_SPI_DEVICE:
                    return "[17] Error, invalid SPI device specified";
                case S4FwDefs.ERR_I2C_NACK:
                    return "[18] Error, I2C NACK";
                case S4FwDefs.ERR_I2C_ARBLOST:
                    return "19] Error, I2C arbitration lost";
                case S4FwDefs.ERR_I2C_BUSERR:
                    return "[20] Error, I2C bus error";
                case S4FwDefs.ERR_I2C_BUSY:
                    return "[21] Error, I2C busy";
                case S4FwDefs.ERR_I2C_SLAVENAK:
                    return "[22] Error, I2C slave NACK";
                case S4FwDefs.ERR_I2C_UNKNOWN:
                    return "[23] Error, unknown I2C problem";
                case S4FwDefs.ERR_CFG_ADC:
                    return "[24] Error, configure ADC error";
                case S4FwDefs.ERR_INVALID_PWM_DUTY_CYCLE:
                    return "[25] Error, invalid PWM duty cycle";
                case S4FwDefs.ERR_INVALID_PWM_RATE:
                    return "[26] Error, invalid PWM rate";
                case S4FwDefs.ERR_WRITING_CALDATA:
                    return "[27] Error writing cal data to EEPROM";
                case S4FwDefs.ERR_READING_CALDATA:
                    return "[28] Error reading cal data from EEPROM";
                case S4FwDefs.ERR_TEMPADC_NOTREADY:
                    return "[29] Error, temperature ADC not ready";
                case S4FwDefs.ERR_TEMPADC_INVALID:
                    return "[30] Error, temperature ADC not valid";
                case S4FwDefs.ERR_INVALID_RF_CHANNEL:
                    return "[31] Error, invalid RF channel. 1-4 allowed";
                case S4FwDefs.ERR_CALDATA_INVALID:
                    return "[32] Error, caldata invalid";
                case S4FwDefs.ERR_LOW_POWER_NOT_SUPPORTED:
                    return "[33] Error, power below 40dBm not supported yet";
                case S4FwDefs.ERR_CALDATA_TOO_LARGE:
                    return "[34] Error, caldata too large";
                case S4FwDefs.ERR_INVALID_IQOFFSET:
                    return "[35] Error, invalid IQ offset value";
                case S4FwDefs.ERR_NO_PLL_LOCK:
                    return "[36] Error, no PLL_LOCK detected";
                case S4FwDefs.ERR_CMD_TIMEOUT:
                    return "[37] Error, command timeout";

                case S4FwDefs.ERR_TAG_NOT_FOUND:
                    return "[45] Error, Tag not found";

                case S4FwDefs.ERR_TAG_TOO_LONG:
                    return "[46] Error, Tag name too long(16 max)";

                case S4FwDefs.ERR_TAG_NO_EQUALS:
                    return "[47] Error, Tag data missing = sign";

                case S4FwDefs.ERR_TAG_NAME_LEN:
                    return "[48] Error, Tag name >16 character limit";

                case S4FwDefs.ERR_TAG_VAL_LEN:
                    return "[49] Error, Tag value >255 byte limit";

                case S4FwDefs.ERR_NO_TAG_DELIMITER:
                    return "[50] Error, Tag data missing delimiter(| character in EEPROM)";

                case S4FwDefs.ERR_TAG_GENERAL:
                    return "[51] Error, unknown Tag error";


                case S4FwDefs.ERR_NO_MEMORY:
                    return "[62] Error, out of memory";

                case S4FwDefs.ERR_I2C_ZEROBYTES:
                    return "[63] Error, 0 byte length in I2C read or write";

                case S4FwDefs.ERR_SPI_ZEROBYTES:
                    return "[64] Error, 0 byte length in SPI IO";

                default:
                case S4FwDefs.ERR_UNKNOWN:
                    return "[100] Unknown error";
            }
        }

        // private methods

        /// <summary>
        /// Returns # of bytes written, 0 means failed
        /// </summary>
        /// <param name="msg"></param>
        /// <param name="socket"></param>
        /// <returns></returns>
        int Send(string msg, Socket socket)
        {
            if (!msg.EndsWith("\n"))
                msg += "\n";    // Must terminate in order to execute
            byte[] msgBytes = Encoding.ASCII.GetBytes(msg);
            return socket.Send(msgBytes);
        }

        /// <summary>
        /// Returns # of bytes read. On success the response 
        /// arg is updated
        /// </summary>
        /// <param name="socket"></param>
        /// <param name="response"></param>
        /// <returns></returns>
        int Receive(Socket socket, ref string response)
        {
            byte[] recBuff = new byte[1024];
            response = "";
            int bytesReceived = 0;
            int newBytes;
            DateTime now = DateTime.Now;
            //bool timeout = false;
            while (!response.EndsWith(">>>"))
            {
                newBytes = socket.Receive(recBuff);
                bytesReceived += newBytes;
                if (newBytes > 0)
                {
                    string next = Encoding.ASCII.GetString(recBuff, 0, newBytes);
                    response += next;
                }

                if(DateTime.Now.Subtract(now).TotalMilliseconds > 2000)
                {
                //    timeout = true;
                    response += "\r\n**Timeout waiting for S4 prompt(>>>)**";
                    break;
                }
            }
            return bytesReceived;
        }

        //bool DiscoverIPAdressViaUDP(ref IPAddress sc_IPAddress)
        //{
        //    bool success = false;
        //    //string msg = "0000~" + _macAddress + "~Blah:SC6000~";
        //    //byte[] msgBytes = Encoding.ASCII.GetBytes(msg);

        //    // Create a list of all the network interface on this computer that have valid IPv4 IP Addresses
        //    NetworkInterface[] computerNetInterfaces = NetworkInterface.GetAllNetworkInterfaces();
        //    List<IPAddress> validInterfaceAddresses = new List<IPAddress>();

        //    foreach (NetworkInterface ni in computerNetInterfaces)
        //    {
        //        // Each network interface may have multiple addresses, but we're only interested in the IPv4
        //        // address
        //        IPInterfaceProperties ipProps = ni.GetIPProperties();
        //        foreach (IPAddressInformation uniAddrInfo in ipProps.UnicastAddresses)
        //        {
        //            IPAddress ipAddr = uniAddrInfo.Address;
        //            // AddressFamily.InterNetwork is IPv4 address
        //            // Only grab address of network interfaces
        //            //      that are IPv4
        //            // AND  it's not a loopback (It wouldn't be bad to broadcast to the loopback, but why bother)
        //            // AND  The network interface is running.
        //            if ( (ipAddr.AddressFamily == AddressFamily.InterNetwork) &&
        //                 (ni.NetworkInterfaceType != NetworkInterfaceType.Loopback) &&
        //                 (ni.OperationalStatus == OperationalStatus.Up) )
        //            {
        //                if(IPAddressExtensions.IsInSameSubnet(ipAddr, _myAddress, _subnetMask))
        //                   validInterfaceAddresses.Add(ipAddr);  // This is the adapter we want to use
        //            }
        //        }
        //    }

        //    return success;
        //}

        /// <summary>
        /// Attempts to establish communication with the S4, 
        /// open a telnet socket with the IP address
        /// </summary>
        public void Connect()
        {
            // Only allow a single connection attempt at a time
            // And do nothing if already connected
            if ((_connectionStatus == ConnectionStatus.Connecting) ||
                (_connectionStatus == ConnectionStatus.Connected))
            {
                return;
            }

            _connectionStatus = ConnectionStatus.Connecting;
            // We have the IP Address, attempt to create a TCP socket and read initial data from the S4
            _endPoint = new IPEndPoint(_s4Address, 23);
            _socket = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
            _socket.ReceiveTimeout = 2000;
            _socket.SendTimeout = 2000;
            _socket.Connect(_endPoint);
            // Read initial status from the S4
            int status = ExecuteCommand("version", ref _response);
            if (status == 0)
                _connectionStatus = ConnectionStatus.Connected;
            else
                _connectionStatus = ConnectionStatus.Disconnected;
        }

        /// <summary>Disconnects and terminates the status thread</summary>
        public void Disconnect()
        {
            if (_connectionStatus == ConnectionStatus.Disconnected)
            {
                // Nothing to do if already disconnected
                return;
            }

            _connectionStatus = ConnectionStatus.Disconnecting;
            if (_socket != null)
            {
                if (_socket.Connected)
                {
                    _socket.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.DontLinger, true);
                    _socket.Disconnect(false);
                }
                _socket.Close();
            }
        }

        /// <summary>Provides text description of the class</summary>
        public string DeviceTypeString
        {
            get { return "Ampleon S4"; }
        }


        
        /////// Ethernet sample from Blah
        //#region Event Arguement Classes and Event Delegates

        ///// <summary>Event arguments for backlight change events</summary>
        //public class BacklightChangedEventArgs : EventArgs
        //{
        //    /// <summary>True if the backlight is on</summary>
        //    public Boolean BacklightOn;
        //}

        ///// <summary>Backlight Changed event handler signature</summary>
        //public delegate void BacklightChangedEventHandler(object sender, BacklightChangedEventArgs e);

        ///// <summary>Event arguments for normalize mode change events</summary>
        //public class NormalizeModeChangeEventArgs : EventArgs
        //{
        //    /// <summary>True if SC-6000 is in normalize mode</summary>
        //    public Boolean NormalizeActive;
        //}

        ///// <summary>Normalize mode changed event handler signature</summary>
        //public delegate void NormalizeModeChangedEventHandler(object sender, NormalizeModeChangeEventArgs e);

        ///// <summary>Event arguments for zero mode change events</summary>
        //public class ZeroModeChangedEventArgs : EventArgs
        //{
        //    /// <summary>True if SC-6000 is in zero mode</summary>
        //    public Boolean ZeroActive;
        //}

        ///// <summary>Zero mode changed event handler signature</summary>
        //public delegate void ZeroModeChangedEventHandler(object sender, ZeroModeChangedEventArgs e);

        ///// <summary>Event arguments for IO Port changed events</summary>
        //public class DigitalIOPortChangedEventArgs : EventArgs
        //{
        //    /// <summary>Number of the port that had a change</summary>
        //    public SC6000.DigitalIOPort PortNum;
        //    /// <summary>Current state of the port</summary>
        //    public Boolean On;
        //}

        ///// <summary>IO Port Changed event handler signature</summary>
        //public delegate void DigitalIOPortChangedEventHandler(object sender, DigitalIOPortChangedEventArgs e);

        ///// <summary>Event arguments for changes to the ranging of the radiometer</summary>
        //public class RangeChangeEventArgs : EventArgs
        //{
        //    /// <summary>True if current in auto range mode, false for manual range mode</summary>
        //    public Boolean AutoRangeActive;
        //    /// <summary>
        //    /// The currennt range selected on the radiometer, regardless of it was set manually or auto ranged
        //    /// </summary>
        //    public int CurrentRangeNum;
        //}

        ///// <summary>Raised when the radiometer switches auto range and manual range modes</summary>
        //public delegate void RangeModeChangedEventHandler(object sender, RangeChangeEventArgs e);

        ///// <summary>
        ///// Raised whenever the current range number of the radiometer changes, either by manual setting or autoranging
        ///// </summary>
        //public delegate void RangeNumberChangedEventHandler(object sender, RangeChangeEventArgs e);

        //#endregion Event Arguement Classes and Event Delegates

        ///// <summary>SC6000 Radiometer</summary>
        //public class SC6000 : Device
        //{
        //    #region Enums, Structs, and Classes

        //    private class UdpClientAsyncReceiveState
        //    {
        //        public IPEndPoint RemoteSC_EndPoint = null;  // end point of the remote host, i.e. SC-6000
        //        public String response;
        //        public UdpClient UdpClient;
        //        public ManualResetEvent CallbackCompletedEvent;

        //        public UdpClientAsyncReceiveState(UdpClient client)
        //        {
        //            UdpClient = client;
        //            CallbackCompletedEvent = new ManualResetEvent(false);
        //        }
        //    }

        //    private class ThreadDataInput
        //    {
        //        public CalSlotInfo RequestedCalSlot;
        //        public Boolean[] ToggleIOPort;

        //        public Boolean EnabledAutoRangeMode;
        //        public Boolean AutoRangeEnableChangeRequested;

        //        public Boolean BacklightOn;
        //        public Boolean BacklightChangeRequested;

        //        public Boolean NormalizeOn;
        //        public Boolean NormalizeChangeRequested;

        //        public Boolean ZeroOn;
        //        public Boolean ZeroChangeRequested;

        //        public Boolean KeypadLocked;
        //        public Boolean KeypadLockedChangeRequested;

        //        public int RequestedRange;
        //        public Boolean RangeNumChangeRequested;

        //        public InternalCalSlotInfo[] calSlotsToProgram;

        //        public ThreadDataInput()
        //        {
        //            RequestedCalSlot = null;

        //            ToggleIOPort = new Boolean[NumDigitalIOPorts];
        //            for (int i = 0; i < ToggleIOPort.Length; i++)
        //            {
        //                ToggleIOPort[i] = false;
        //            }

        //            EnabledAutoRangeMode = false;
        //            AutoRangeEnableChangeRequested = false;
        //        }

        //        public Boolean CalChangeRequestUnprocessed
        //        {
        //            get
        //            {
        //                // If RequestedCalSlot is not null than a cal slot change
        //                // was requested but not yet cleared by CopyAndClear()
        //                return (RequestedCalSlot != null);
        //            }
        //        }

        //        public ThreadDataInput CopyAndClear()
        //        {
        //            ThreadDataInput retObj = new ThreadDataInput();
        //            retObj.RequestedCalSlot = this.RequestedCalSlot;
        //            this.RequestedCalSlot = null;

        //            for (int i = 0; i < ToggleIOPort.Length; i++)
        //            {
        //                retObj.ToggleIOPort[i] = this.ToggleIOPort[i];
        //                this.ToggleIOPort[i] = false;
        //            }

        //            retObj.EnabledAutoRangeMode = this.EnabledAutoRangeMode;
        //            retObj.AutoRangeEnableChangeRequested = this.AutoRangeEnableChangeRequested;
        //            this.AutoRangeEnableChangeRequested = false;

        //            retObj.RequestedRange = this.RequestedRange;
        //            retObj.RangeNumChangeRequested = this.RangeNumChangeRequested;
        //            this.RangeNumChangeRequested = false;

        //            retObj.BacklightOn = this.BacklightOn;
        //            retObj.BacklightChangeRequested = this.BacklightChangeRequested;
        //            this.BacklightChangeRequested = false;

        //            retObj.NormalizeOn = this.NormalizeOn;
        //            retObj.NormalizeChangeRequested = this.NormalizeChangeRequested;
        //            this.NormalizeChangeRequested = false;

        //            retObj.ZeroOn = this.ZeroOn;
        //            retObj.ZeroChangeRequested = this.ZeroChangeRequested;
        //            this.ZeroChangeRequested = false;

        //            retObj.KeypadLocked = this.KeypadLocked;
        //            retObj.KeypadLockedChangeRequested = this.KeypadLockedChangeRequested;
        //            this.KeypadLockedChangeRequested = false;

        //            if (calSlotsToProgram != null)
        //            {
        //                retObj.calSlotsToProgram = new InternalCalSlotInfo[this.calSlotsToProgram.Length];
        //                for (int i = 0; i < this.calSlotsToProgram.Length; i++)
        //                {
        //                    retObj.calSlotsToProgram[i] = (InternalCalSlotInfo)this.calSlotsToProgram[i].Clone();
        //                }
        //            }
        //            else
        //            {
        //                retObj.calSlotsToProgram = null; // should be null already but just in case
        //            }

        //            this.calSlotsToProgram = null; // clears the request

        //            return retObj;
        //        }
        //    }

        //    private class SC_StatusInfo
        //    {
        //        public int CurrentCalSlot;
        //        public Boolean AutoRangeActive;
        //        public int CurrentRangeNum;
        //        public Boolean ZeroActive;
        //        public Boolean NormalizeActive;
        //        public Boolean BackLightOn;

        //        /// <summary>Parses a status message response string</summary>
        //        /// Status messages are in the form: "R0~SS~C01~A1~R1~Z0~N0~B1~T1"
        //        /// Token
        //        /// [0]      R0  - Standard SC6000 response, 0 indicates no error
        //        /// [1]      SS  - Command echoed back
        //        /// [2]      C01 - Current calibration slot 0 - 99
        //        /// [3]      A1  - Auto range Active 0 = manual mode 1 = auto range mode
        //        /// [4]      R1  - Current PDA750 range number
        //        /// [5]      Z0  - Zero Mode 0 = off 1 = on
        //        /// [6]      N0  - Normalize mode 0 = off 1 = on
        //        /// [7]      B1  - Backlight 0 = off 1 = on
        //        /// [8]      T1  - TCP Mode, not sure the SC-6000 will ever send anything other than 1
        //        public static SC_StatusInfo ParseStatusRespone(String response)
        //        {
        //            SC_StatusInfo statInfo = new SC_StatusInfo();
        //            String[] parts = response.Split('~');

        //            // Calibration slot
        //            String strSlotNum = parts[2].Remove(0, 1); // remove the 'C'
        //            statInfo.CurrentCalSlot = Int32.Parse(strSlotNum);

        //            // Auto range mode
        //            statInfo.AutoRangeActive = ParseBooleanPart(parts[3]);

        //            // PDA750 Range
        //            String strRangeNum = parts[4].Remove(0, 1); // remove the 'R'
        //            statInfo.CurrentRangeNum = Int32.Parse(strRangeNum);

        //            // Zero Mode
        //            statInfo.ZeroActive = ParseBooleanPart(parts[5]);

        //            // Normalize Mode
        //            statInfo.NormalizeActive = ParseBooleanPart(parts[6]);

        //            // Backligth
        //            statInfo.BackLightOn = ParseBooleanPart(parts[7]);

        //            // Ignoring TCP mode: parts[8]

        //            return statInfo;
        //        }

        //        private static Boolean ParseBooleanPart(String strPart)
        //        {
        //            // Ignore the letter at strPart[0]: 'A', 'Z', 'N', or 'B'
        //            if (strPart[1] == '1')
        //            {
        //                return true;
        //            }
        //            else if (strPart[1] == '0')
        //            {
        //                return false;
        //            }
        //            else
        //            {
        //                throw new ApplicationException("SC6000 status message parse error, parsing: " + strPart);
        //            }
        //        }

        //        public SC_StatusInfo Clone()
        //        {
        //            // Shallow copy is OK because all members are reference types.
        //            return (SC_StatusInfo)MemberwiseClone();
        //        }

        //    }

        //    private class ThreadDataOutput
        //    {
        //        public SC_StatusInfo statusInfo;
        //        public Double DetectorReading;
        //        public Boolean[] IOPortOn = new Boolean[NumDigitalIOPorts];

        //    }

        //    #endregion Enums, Structs, and Classes

        //    #region Member fields, constants, delegates and events

        //    // Strings from the SC-6000 must be parsed as doubles with the American style
        //    // of decimal place and thousands separator,
        //    // (I.e. 1,234.01 and not 1.234,01 as in the European Style)
        //    // regardless of the current regional settings on the PC
        //    CultureInfo americanCultureInfo = CultureInfo.GetCultureInfo("en-US");

        //    private const int NumDigitalIOPorts = 8;

        //    private String _macAddress;

        //    private Thread _statusThread;
        //    private ThreadDataOutput _threadOutputData;
        //    private ThreadDataInput _threadInputData;

        //    private List<CalSlotInfo> _calibrationSlotsCollection = new List<CalSlotInfo>();

        //    /// <summary>Occurs when the calibration slot changes</summary>
        //    public event EventHandler SelectedCalibrationSlotChanged;
        //    /// <summary>Occurs when the state of IO port changes</summary>
        //    public event DigitalIOPortChangedEventHandler DigitalIOPortChanged;
        //    /// <summary>Raised when the radiometer switches auto range and manual range modes</summary>
        //    public event RangeModeChangedEventHandler RangeModeChanged;
        //    /// <summary>
        //    /// Raised whenever the current range number of the radiometer changes, either by manual setting or autoranging
        //    /// </summary>
        //    public event RangeNumberChangedEventHandler RangeNumberChanged;
        //    /// <summary>The backlight turned on or off</summary>
        //    public event BacklightChangedEventHandler BacklightOnChanged;
        //    /// <summary>Normalize mode turned on or off</summary>
        //    public event NormalizeModeChangedEventHandler NormalizeModeChanged;
        //    /// <summary>Zero mode turned on or off</summary>
        //    public event ZeroModeChangedEventHandler ZeroModeChanged;

        //    #endregion Member fields, constants, delegates and events

        //    #region Properties

        //    /// <summary>Returns the MAC address supplied to the constructor when the object was created</summary>
        //    public String MAC_Address
        //    {
        //        get
        //        {
        //            return _macAddress;
        //        }
        //    }

        //    ///// <summary>Gets information about the current calibration slot</summary>
        //    //public CalSlotInfo CurrentCalSlot
        //    //{
        //    //    get
        //    //    {
        //    //        lock (_threadOutputData)
        //    //        {
        //    //            CalSlotInfo retVal;

        //    //            if (_threadOutputData.CurrentCalibration == null)
        //    //            {
        //    //                // This can happen if were not yet connected and there aren't any external cals
        //    //                // Return a blank cal
        //    //                retVal = new InternalCalSlotInfo();
        //    //            }
        //    //            else
        //    //            {
        //    //                retVal = _threadOutputData.CurrentCalibration.Clone();
        //    //            }

        //    //            return retVal;
        //    //        }
        //    //    }
        //    //}

        //    ///// <summary>Index of current cal slot in AllCalibrationSlots[] array</summary>
        //    //public int CurrentCalSlotIndex
        //    //{
        //    //    get
        //    //    {
        //    //        int index;
        //    //        lock (_threadOutputData)
        //    //        {
        //    //            for (index = 0; index < _calibrationSlotsCollection.Count; index++)
        //    //            {
        //    //                if (_threadOutputData.CurrentCalibration == _calibrationSlotsCollection[index])
        //    //                {
        //    //                    // Break out of loop, index is now correct
        //    //                    break;
        //    //                }
        //    //            }
        //    //        }

        //    //        return index;
        //    //    }
        //    //}

        //    ///// <summary>AArray of both the internal and external calibrations</summary>
        //    //public CalSlotInfo[] AllCalibrationSlots
        //    //{
        //    //    get
        //    //    {
        //    //        //return (CalSlotInfo[])_calibrationSlots.Clone();
        //    //        CalSlotInfo[] retArray = new CalSlotInfo[_calibrationSlotsCollection.Count];
        //    //        for (int i = 0; i < retArray.Length; i++)
        //    //        {
        //    //            retArray[i] = _calibrationSlotsCollection[i].Clone();
        //    //        }

        //    //        return retArray;
        //    //    }
        //    //}

        //    ///// <summary>Array for the calibration slots that are stored in the SC-6000</summary>
        //    //public InternalCalSlotInfo[] InternalCalibrationSlots
        //    //{
        //    //    get
        //    //    {
        //    //        List<InternalCalSlotInfo> interns = new List<InternalCalSlotInfo>();

        //    //        foreach (CalSlotInfo cSlot in _calibrationSlotsCollection)
        //    //        {
        //    //            if (cSlot is InternalCalSlotInfo)
        //    //            {
        //    //                interns.Add((InternalCalSlotInfo)cSlot);
        //    //            }
        //    //        }

        //    //        return interns.ToArray();
        //    //    }
        //    //}

        //    ///// <summary>Array of the calibration slots that are not done in the SC-6000</summary>
        //    //public ExternalCalSlotInfo[] ExternalCalibration
        //    //{
        //    //    get
        //    //    {
        //    //        List<ExternalCalSlotInfo> externs = new List<ExternalCalSlotInfo>();

        //    //        foreach (CalSlotInfo cSlot in _calibrationSlotsCollection)
        //    //        {
        //    //            if (cSlot is ExternalCalSlotInfo)
        //    //            {
        //    //                externs.Add((ExternalCalSlotInfo)cSlot);
        //    //            }
        //    //        }

        //    //        return externs.ToArray();
        //    //    }
        //    //}


        //    ///// <summary>
        //    ///// Gets the last read detector value
        //    ///// Use the current cal slot for units
        //    ///// </summary>
        //    //public Double DetectorReading
        //    //{
        //    //    get
        //    //    {
        //    //        lock (_threadOutputData)
        //    //        {
        //    //            return _threadOutputData.DetectorReading;
        //    //        }
        //    //    }
        //    //}

        //    ///// <summary>True if the SC-6000 is in auto range mode</summary>
        //    //public Boolean AutoRangeActive
        //    //{
        //    //    get
        //    //    {
        //    //        lock (_threadOutputData)
        //    //        {
        //    //            return _threadOutputData.statusInfo.AutoRangeActive;
        //    //        }
        //    //    }
        //    //}

        //    ///// <summary>Current range selected on the SC-6000, either manually set or auto ranged</summary>
        //    //public int CurrentRange
        //    //{
        //    //    get
        //    //    {
        //    //        lock (_threadOutputData)
        //    //        {
        //    //            return _threadOutputData.statusInfo.CurrentRangeNum;
        //    //        }
        //    //    }
        //    //}

        //    ///// <summary>True if the backlight is on</summary>
        //    //public Boolean BacklightOn
        //    //{
        //    //    get
        //    //    {
        //    //        lock (_threadOutputData)
        //    //        {
        //    //            return _threadOutputData.statusInfo.BackLightOn;
        //    //        }
        //    //    }
        //    //    set
        //    //    {
        //    //        if (this.IsConnected == false)
        //    //        {
        //    //            return; // do nothing if not connected
        //    //        }

        //    //        lock (_threadInputData)
        //    //        {
        //    //            _threadInputData.BacklightOn = value;
        //    //            _threadInputData.BacklightChangeRequested = true;
        //    //        }
        //    //    }
        //    //}

        //    ///// <summary>True if the SC-6000 is in normalize mode</summary>
        //    //public Boolean NormalizeActive
        //    //{
        //    //    get
        //    //    {
        //    //        lock (_threadOutputData)
        //    //        {
        //    //            return _threadOutputData.statusInfo.NormalizeActive;
        //    //        }
        //    //    }
        //    //    set
        //    //    {
        //    //        if (this.IsConnected == false)
        //    //        {
        //    //            return; // do nothing if not connected
        //    //        }

        //    //        lock (_threadInputData)
        //    //        {
        //    //            _threadInputData.NormalizeOn = value;
        //    //            _threadInputData.NormalizeChangeRequested = true;
        //    //        }
        //    //    }
        //    //}

        //    ///// <summary>True if the SC-6000 is in zero mode</summary>
        //    //public Boolean ZeroActive
        //    //{
        //    //    get
        //    //    {
        //    //        lock (_threadOutputData)
        //    //        {
        //    //            return _threadOutputData.statusInfo.ZeroActive;
        //    //        }
        //    //    }
        //    //    set
        //    //    {
        //    //        if (this.IsConnected == false)
        //    //        {
        //    //            return; // do nothing if not connected
        //    //        }

        //    //        lock (_threadInputData)
        //    //        {
        //    //            _threadInputData.ZeroOn = value;
        //    //            _threadInputData.ZeroChangeRequested = true;
        //    //        }
        //    //    }
        //    //}

        //    ///// <summary>Locks or unlocks the keypad</summary>
        //    //public Boolean LockKeypad
        //    //{
        //    //    set
        //    //    {
        //    //        if (this.IsConnected == false)
        //    //        {
        //    //            return; // do nothing if not connected
        //    //        }

        //    //        lock (_threadInputData)
        //    //        {
        //    //            _threadInputData.KeypadLocked = value;
        //    //            _threadInputData.KeypadLockedChangeRequested = true;
        //    //        }
        //    //    }
        //    //}

        //    #endregion Properties

        //    #region Constructors, Destructors, and Finalizers

        //    /// <summary>Constructor</summary>
        //    /// <param name="deviceID">User defined identifier, may be anything</param>
        //    /// <param name="MacAddress">
        //    /// MAC address of the SC-6000, used to get the current DHCP assigned IP Address
        //    /// The format of the MAC is six groups hexadecimal digits, separtated by colons.
        //    /// e.g."00:90:C2:DA:75:93"
        //    /// </param>
        //    public void FindS4(String deviceID, String MacAddress)
        //    {
        //        _macAddress = MacAddress;
        //        _threadInputData = new ThreadDataInput();
        //        _threadOutputData = new ThreadDataOutput();
        //    }

        //    internal void FindS4(XmlElement xmlElement)
        //    {
        //        _threadInputData = new ThreadDataInput();
        //        _threadOutputData = new ThreadDataOutput();

        //        Boolean macAddressParsed = false;

        //        foreach (XmlNode node in xmlElement.ChildNodes)
        //        {
        //            switch (node.Name)
        //            {
        //                case "MAC_Address":
        //                    _macAddress = node.FirstChild.Value;
        //                    macAddressParsed = true;
        //                    break;
        //            }
        //        }

        //        if (macAddressParsed == false)
        //        {
        //            throw new ApplicationException("The required MAC address was not supplied");
        //        }

        //        // check if any External calibration slots are defined in the config file
        //        String xPath = typeof(ExternalCalSlotInfo).Name;
        //        XmlNodeList exCalNodes = xmlElement.SelectNodes(xPath);

        //        foreach (XmlElement exCalElement in exCalNodes)
        //        {
        //            ExternalCalSlotInfo exCal = new ExternalCalSlotInfo(exCalElement);
        //            _calibrationSlotsCollection.Add(exCal);
        //        }
        //    }

        //    #endregion Constructors, Destructors, and Finalizers

        //    #region Methods

        //    ///// <summary>
        //    ///// Write the calibration slots to the SC-6000
        //    ///// </summary>
        //    //public void SendCalibrationDataToSC(InternalCalSlotInfo[] calSlots)
        //    //{
        //    //    if (this.IsConnected == false)
        //    //    {
        //    //        return;
        //    //    }

        //    //    lock (_threadInputData)
        //    //    {
        //    //        if (_threadInputData.calSlotsToProgram != null)
        //    //        {
        //    //            // we can only process one request at a time
        //    //            return;
        //    //        }
        //    //        else
        //    //        {
        //    //            _threadInputData.calSlotsToProgram = calSlots;

        //    //            _threadInputData.calSlotsToProgram = new InternalCalSlotInfo[calSlots.Length];
        //    //            for (int i = 0; i < calSlots.Length; i++)
        //    //            {
        //    //                _threadInputData.calSlotsToProgram[i] = (InternalCalSlotInfo)calSlots[i].Clone();
        //    //            }
        //    //        }
        //    //    }
        //    //}

        //    ///// <summary>Selects the calibration slot</summary>
        //    ///// <param name="requestedSlotIndex">
        //    ///// The slot index is the index of the AllCalibrationSlots array of the cal slot you want to select
        //    ///// </param>
        //    //public void SetCalibrationSlot(int requestedSlotIndex)
        //    //{
        //    //    if (this.IsConnected == false)
        //    //    {
        //    //        return;
        //    //    }

        //    //    if ((requestedSlotIndex < 0) ||
        //    //        (requestedSlotIndex >= _calibrationSlotsCollection.Count) ||
        //    //        (_calibrationSlotsCollection.Count == 0))
        //    //    {
        //    //        throw new ApplicationException("Calibration slot requested does not exist");
        //    //    }

        //    //    lock (_threadInputData)
        //    //    {
        //    //        // We can't process more than one request at time
        //    //        // RequestCalSlot gets reset to null when the scan thread processes the request
        //    //        if (_threadInputData.CalChangeRequestUnprocessed == false)
        //    //        {
        //    //            _threadInputData.RequestedCalSlot = _calibrationSlotsCollection[requestedSlotIndex];
        //    //        }
        //    //        //else
        //    //        //{
        //    //        //    ; // Do nothing
        //    //        // Could maybe indicate some kind of error back to caller
        //    //        //}
        //    //    }
        //    //}

        //    ///// <summary>Sets either auto range or manual range mode on the SC-6000</summary>
        //    //public void EnableAutoRangeMode(Boolean enabled)
        //    //{
        //    //    if (this.IsConnected == false)
        //    //    {
        //    //        return; // do nothing if not connected
        //    //    }

        //    //    lock (_threadInputData)
        //    //    {
        //    //        _threadInputData.EnabledAutoRangeMode = enabled;
        //    //        _threadInputData.AutoRangeEnableChangeRequested = true;
        //    //    }
        //    //}

        //    ///// <summary>Set the range for the radiometer, valid values from 1 to 7</summary>
        //    ///// <returns>false if unable to change the range because we're currently in auto range mode</returns>
        //    ///// <exception cref="ApplicationException">if value is less than 1 or greater 7</exception>
        //    //public Boolean SetRange(int rangeNum)
        //    //{
        //    //    if (this.IsConnected == false)
        //    //    {
        //    //        return false;
        //    //    }

        //    //    if ((rangeNum < 1) || (rangeNum > 7))
        //    //    {
        //    //        throw new ApplicationException("Invalid range value, valid values are 1 to 7");
        //    //    }

        //    //    lock (_threadOutputData)
        //    //    {
        //    //        if (_threadOutputData.statusInfo.AutoRangeActive)
        //    //        {
        //    //            return false;
        //    //        }
        //    //        else
        //    //        {
        //    //            _threadInputData.RequestedRange = rangeNum;
        //    //            _threadInputData.RangeNumChangeRequested = true;
        //    //            return true;
        //    //        }
        //    //    }
        //    //}

    }

    public static class IPAddressExtensions
    {
        public static IPAddress GetBroadcastAddress(this IPAddress address, IPAddress subnetMask)
        {
            byte[] ipAdressBytes = address.GetAddressBytes();
            byte[] subnetMaskBytes = subnetMask.GetAddressBytes();

            if (ipAdressBytes.Length != subnetMaskBytes.Length)
                throw new ArgumentException("Lengths of IP address and subnet mask do not match.");

            byte[] broadcastAddress = new byte[ipAdressBytes.Length];
            for (int i = 0; i < broadcastAddress.Length; i++)
            {
                broadcastAddress[i] = (byte)(ipAdressBytes[i] | (subnetMaskBytes[i] ^ 255));
            }
            return new IPAddress(broadcastAddress);
        }

        public static IPAddress GetNetworkAddress(this IPAddress address, IPAddress subnetMask)
        {
            byte[] ipAdressBytes = address.GetAddressBytes();
            byte[] subnetMaskBytes = subnetMask.GetAddressBytes();

            if (ipAdressBytes.Length != subnetMaskBytes.Length)
                throw new ArgumentException("Lengths of IP address and subnet mask do not match.");

            byte[] broadcastAddress = new byte[ipAdressBytes.Length];
            for (int i = 0; i < broadcastAddress.Length; i++)
            {
                broadcastAddress[i] = (byte)(ipAdressBytes[i] & (subnetMaskBytes[i]));
            }
            return new IPAddress(broadcastAddress);
        }

        public static bool IsInSameSubnet(this IPAddress address2, IPAddress address, IPAddress subnetMask)
        {
            IPAddress network1 = address.GetNetworkAddress(subnetMask);
            IPAddress network2 = address2.GetNetworkAddress(subnetMask);

            return network1.Equals(network2);
        }
    }
}
