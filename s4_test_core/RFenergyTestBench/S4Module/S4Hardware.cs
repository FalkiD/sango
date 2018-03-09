using System;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Runtime.CompilerServices;

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

        // Wow, takes > 1 second to get I2C response back??
        const int S4_TIMEOUT = 2000;    // ms, socket timeout

        // S4 default ip address
        IPAddress           _s4Address   = new IPAddress(new byte[] { 192, 168, 10, 3 });
        IPAddress           _myAddress   = new IPAddress(new byte[] { 192, 168, 10, 10 });
        IPAddress           _subnetMask  = new IPAddress(new byte[] { 255, 255, 255, 0 });
        ConnectionStatus    _connectionStatus;
        IPEndPoint          _endPoint;
        string              _response;
        Socket              _socket = null;
        int                 _timeoutMs = S4_TIMEOUT;  // default timeout waiting for response/prompt

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
                Connect();                  // sets _connectionStatus
                if (_connectionStatus == ConnectionStatus.Connected)
                {
                    S4Module.WriteMessage("Sango S4 plasma ignition source connected.");
                    if(_response != null && _response.Length > 0)
                    {
                        string[] lines = _response.Split(new char[] { '\n' });
                        foreach (string line in lines)
                        {
                            string next = line;
                            if (next.Length == 0)
                                continue;
                            if (next.EndsWith("\r"))
                                next = next.Substring(0, next.Length - 1);
                            S4Module.WriteMessage(next);
                        }
                    }
                    return 0;
                }
                else
                {
                    S4Module.WriteMessage("** Error opening S4 socket **");
                    return 100;
                }
            }
            catch (Exception ex)
            {
                S4Module.WriteMessage(string.Format("Exception opening S4 socket:{0}", ex.Message));
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
        [MethodImpl(MethodImplOptions.Synchronized)]
        public int ExecuteCommand(string command, ref string response)
        {
            bool status = WriteCommand(command);
            if (status)
            {
                System.Threading.Thread.Sleep(150);
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
            int newBytes = 0;
            DateTime now = DateTime.Now;
            //bool timeout = false;
            _socket.ReceiveTimeout = 100;   // Make this more responsive/granular
            while (!response.EndsWith(">"))
            {
                try { newBytes = socket.Receive(recBuff); }
                catch(SocketException ex)
                {
                    if (ex.SocketErrorCode != SocketError.TimedOut)
                        throw;
                }
                bytesReceived += newBytes;
                if (newBytes > 0)
                {
                    string next = Encoding.ASCII.GetString(recBuff, 0, newBytes);
                    response += next;
                }

                if(DateTime.Now.Subtract(now).TotalMilliseconds > _timeoutMs)
                {
                //    timeout = true;
                    response += "\r\n**Timeout waiting for S4 prompt(>)**";
                    break;
                }
            }
            return bytesReceived;
        }

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
            _socket.ReceiveTimeout = S4_TIMEOUT;
            _socket.SendTimeout = S4_TIMEOUT;
            _socket.Connect(_endPoint);
            _connectionStatus = _socket.Connected ? ConnectionStatus.Connected : ConnectionStatus.Disconnected;
            WaitForPrompt();
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

        /// <summary>
        /// Wait for S4 prompt, can be ">", ">>", or ">>>" 
        /// depending on login mode
        /// </summary>
        /// <returns>bytes read</returns>
        public bool WaitForPrompt()
        {
            System.Threading.Thread.Sleep(100);
            int bytes = Receive(_socket, ref _response);
            //string more = "";
            //int saved = _timeoutMs;
            //_timeoutMs = 100;
            //int extra = Receive(_socket, ref more);
            //if (extra > 0)
            //    _response += more;
            //extra = Receive(_socket, ref more);
            //if (extra > 0)
            //    _response += more;
            //_timeoutMs = saved;
            return bytes > 0 ? true : false;
        }

        /// <summary>Provides text description of the class</summary>
        public string DeviceTypeString
        {
            get { return "Ampleon S4"; }
        }
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
