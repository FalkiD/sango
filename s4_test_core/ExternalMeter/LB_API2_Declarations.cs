using System;
using System.Collections.Generic;
using System.Text;
using System.Runtime.InteropServices;
//
namespace LadyBug_TestHarness
{
    class LB_API2_Declarations
    {
        public const int DFLT_MTX_TO = 10000;
        public const int ADDRESS_MIN = 1;
        public const int ADDRESS_MAX = 255;

        public const double MIN_FREQ = 10000000.0D;
        public const double MAX_FREQ = 10000000000.0D;

        public const int MIN_AVERAGES = 1;
        public const int MAX_AVERAGES = 100000;
        public const double MAX_PK_PLS_CRIT = 200.0D;
        public const double MIN_PK_PLS_CRIT = 0.001; //  must be greater than 0.0
        public const double MAX_OFFSET = 200.0D;
        public const double MIN_OFFSET = -200.0D;

        public const int FIRST_REG_INDEX = 0;
        public const int LAST_REG_INDEX = 19;
        public const int NUM_SAVE_RECALL_STATES = 20;
        public const int MAX_NUMBER_OF_SENSORS = 16;
        public const int MAX_NUM_RESP_PTS = 201;
        public const int DEFAULT_TRIG_TIMEOUT = 3000; //  3 seconds for default trigger timeout
        public const int MAX_TRIGGER_TIMEOUE = 30000; //  30 seconds is max timeout
        public const double DEFAULT_FREQ = 1000000000.0D;
        public const int DEFAULT_AVERAGES = 75;
        public const double DEFAULT_PULSE_CRIT = 3.0D;
        public const double DEFAULT_RCDR_1V_LEVEL = 10.0D;
        public const double DEFAULT_RCDR_0V_LEVEL = -20.0D;
        public const double MIN_DC_PER_CENT = 0.001;
        public const double MAX_DC_PER_CENT = 100.0D;
        public const double MIN_DC_DECIMAL = 0.00001;
        public const double MAX_DC_DECIMAL = 1.0D;

        public enum SWEEP_TIME
        {
            INVALID_SWP_TIME = -1,			// invalid sweep time
            ST_10 = 0,			    // 10 USEC
            ST_20 = 1,			    // 20 USEC
            ST_50 = 2,			    // 50 USEC

            ST_100 = 3,			    // 100 USEC
            ST_200 = 4,			    // 200 USEC
            ST_500 = 5,			    // 500 USEC

            ST_1000 = 6,			// 1000 USEC OR 1 MSEC
            ST_2000 = 7,			// 2000 USEC OR 2 MSEC
            ST_5000 = 8,			// 5000 USEC OR 5 MSEC

            ST_10000 = 9,			// 10000 USEC OR 10 MSEC
            ST_20000 = 10,			// 20000 USEC OR 20 MSEC
            ST_50000 = 11,			// 50000 USEC RO 50 MSEC

            ST_100000 = 12,			// 100000 USEC OR 100 MSEC
            ST_200000 = 13,			// 200000 USEC OR 200 MSEC
            ST_500000 = 14,			// 500000 USEC OR 500 MSEC

            ST_1000000 = 15,			// 1000000 USEC OR 1000 MSEC OR 1 SEC

            SD_1200 = 16,			// 1200 USEC OR 1.2 MSEC DELAYED SWEEP - 96 passes, used with 10usec to 200usec sweep times for delays <= 1 msec
            SD_5200 = 17,			// 5200 USEC OR 5.2 MSEC DELAYED SWEEP - 96 passes, used with 10usec to 200usec sweep times for delays <= 5 msec
            SD_10200 = 18,			// 10200 USEC OR 10.2 MSEC DELAYED SWEEP - 96 passes, used with 10usec to 200usec sweep times for delays <= 10 msec
            SD_10500 = 19,			// 10500 USEC OR 10.5 MSEC DELAYED SWEEP - 48 passes, used with 500usec to sweep times for delays <= 10 msec
            SD_20000 = 20,			// 20000 USEC OR 20.0 MSEC DELAYED SWEEP - 24 passes, used with 1msec to 10msec sweep times for delays <= 10 msec
            SD_30000 = 21,			// 30000 USEC OR 30.0 MSEC DELAYED SWEEP - 12 passes, used with 20msec sweep times for delays <= 10 msec
            SD_60000 = 22,			// 60000 USEC OR 60.0 MSEC DELAYED SWEEP - 6 passes, used with 50msec sweep times for delays <= 10 msec
        }

        public enum MODEL_NUMBER
        { //  Enumeration of model numbers
            MNUknwn = -1,
            LB4xxA = 0,
            LB478A = 1,
            LB479A = 2,
            LB480A = 3,
            LB559A = 4,							// 12.5GHz CW Sensor
            LB579A = 5,							// 18.0GHz CW Sensor
            LB589A = 6,							// 26.0GHz CW Sensor
            GUknwn = -1,
            GOEMOEM = 64,
            GUnSet = 65,							// Required for accounting purposes
            GT8888A = 66,							// GT-8888A = LB478A  10 MHz to 10 GHz  CW
            GT8551A = 67,							// GT-8551A = LB479A  10 MHz to 10 GHz  CW and Modulation
            GT8552A = 68,							// GT-8552A = LB480A  100 MHz to 10 GHz  CW and Pulse Profiling
            GT8553A = 69,							// GT-8553A = LB579A  10 MHz to 18 GHz  CW
            GT8554A = 70,							// GT-8554A = LB589A  10 MHz to 26.5 GHz  CW
        }

        public enum PWR_UNITS
        {
            DBM = 0,
            DBW = 1,
            DBKW = 2,
            DBUV = 3,
            W = 4,
            V = 5,
            DBREL = 6,
        }

        public enum FEATURE_STATE
        {
            ST_OFF = 0,
            ST_ON = 1,
        }

        public enum LIMIT_STYLE
        {
            LIMITS_OFF = 0,
            SINGLE_SIDED = 1,
            DOUBLE_SIDED = 2,
        }

        public enum SS_RULE
        {
            PASS_LT = 0,
            PASS_LTE = 1,
            PASS_GT = 2,
            PASS_GTE = 3,
        }

        public enum DS_RULE
        {
            PASS_BETWEEN_EXC = 0,
            PASS_BETWEEN_INC = 1,
            PASS_OUTSIDE_EXC = 2,
            PASS_OUTSIDE_INC = 3,
        }

        public enum PASS_FAIL_RESULT
        {
            PASS = 0,
            FAIL_LOW = 1,
            FAIL_HIGH = 2,
            FAIL_BETWEEN_LIMIT_EXC = 3,
            FAIL_BETWEEN_LIMIT_INC = 4,
            NO_DETERMINATION = 5,
            //  not limited to the following reasons:
            //       - limits are not enabled
            //       - limits are not specified
            //       - valid measurement not made (timeout?)
        }

        public enum SVC_WTY_OPTS
        {
            NO_SVC_WTY_OPT = 0,
            CW03 = 1,
            C03 = 2,
            W03 = 3,
        }

        public enum AVG_MODE
        {
            AVG_OFF = 0,
            AVG_AUTO_RESET = 1,
            AVG_MANUAL_RESET = 2,
        }

        public enum MARKER_MODE
        {
            MKR_OFF = 0,
            NORMAL_MKR = 1,
            DELTA_MKR = 2
        }

        public enum GATE_MODE
        {
            GATE_OFF = 0,
            GATE_ON = 1
        }
         
        public enum CONN_TYPES
        {
            NOT_SET = 0,
            SMA_F = 1,
            SMA_M = 2,
            TNC_F = 3,
            TNC_M = 4,
            N_TYPE_F = 5,
            N_TYPE_M = 6,
        }

        public enum TRIGGER_EDGE
        {
            POSITIVE = 0,
            NEGATIVE = 1
        }

        public enum TRIGGER_SOURCE
        {
            INT_AUTO_LEVEL = 0,
            INTERNAL = 1,
            EXTERNAL = 2
        }

        public enum TRIGGER_OUT_MODE
        {
            TRG_OUT_DISABLED = 0,
            TRG_OUT_ENABLED_NON_INV = 1,
            TRG_OUT_ENABLED_INV = 2
        }

        public enum HDWE_OPT_VAL
        { // Used for recorder out, trigger in/out, filters and best match hardware options

            OPT_OFF = 0,
            OPT_ON = 1,
        }

        public enum FLT_POLES
        {
            ONE_POLE = 0,
            TWO_POLES = 1,
            FOUR_POLES = 2
        };

        public enum FLT_CO_FREQ
        {
            FLT_UNK = -1,						// filter unknown
            FLT_DIS = 0,						// filters disabled
            FLT_100K = 1,						// 100KHz
            FLT_200K = 2,						// 200KHz
            FLT_300K = 3,						// 300KHz
            FLT_500K = 4,						// 500KHz
            FLT_1M = 5,							// 1MHz
            FLT_2M = 6,							// 2MHz
            FLT_3M = 7,							// 3MHz
            FLT_5M = 8,							// 5MHz
            FLT_MAX = 9                         // >=10MHz
        };

        public struct SensorDescription
        {
            public int DeviceIndex;
            public int DeviceAddress;
            public string SerialNumber;
        }

        // !!!!changed char SerialNumber to eight characters for byte alignment reasons...made bugs go away!!!!
        [StructLayoutAttribute(LayoutKind.Sequential, Size=16, CharSet=CharSet.Ansi)]
        public struct SDByte
        {
            public int DeviceIndex;
            public int DeviceAddress;
            public byte SNByte0;
            public byte SNByte1;
            public byte SNByte2;
            public byte SNByte3;
            public byte SNByte4;
            public byte SNByte5;
            public byte SNByte6;
            public byte SNByte7;
            public string SN()
            {
                string strSN = string.Concat((char)SNByte0, (char)SNByte1, (char)SNByte2);
                strSN = string.Concat(strSN, (char)SNByte3, (char)SNByte4, (char)SNByte5);
                return strSN;
            }
        }

        public struct SensorDescrption
        {
            public int DeviceIndex;
            public int DeviceAddress;
            public string SerialNumber;
        }

        [StructLayoutAttribute(LayoutKind.Sequential)]
        public struct ResponsePoints
        {
            public double Frequency;
            public double Amplitude;
        }

        public struct Peak
        {
            public int trIdx;												// index where peak was found
            public double value;											// value of peak
        };

        public static bool validDeviceSelected = false;

//=========================================================================================
// Functions
//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_DriverVersion();
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetFirmwareVersion(int addr, ref byte buff, int buffLen);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int PP_GetPeaks_Idx(int addr, ref Peak peaks, int maxPks, ref int pksUsed);	
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int PP_GetPeaksFromTr_Idx(ref double tr, 
                                                        int trLen, 
                                                        int units, 
                                                        double pkCrit, 
                                                        double measThresh, 
                                                        ref Peak peaks, 
                                                        int maxPks, 
                                                        ref int pksUsed);

        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int PP_GetPeaks_Val(int addr, ref Peak peaks, int maxPks, ref int pksUsed);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int PP_GetPeaksFromTr_Val(ref double tr,
                                                        int trLen, 
                                                        int units, 
                                                        double pkCrit, 
                                                        double measThresh, 
                                                        ref Peak peaks, 
                                                        int maxPks, 
                                                        ref int pksUsed);

        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int PP_MarkerToPk(int addr, int mrkIdx);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int PP_MarkerToLowestPk(int addr, int mrkIdx);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int PP_MarkerPkLower(int addr, int mrkIdx);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int PP_MarkerPkHigher(int addr, int mrkIdx);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int PP_MarkerToFirstPk(int addr, int mrkIdx);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int PP_MarkerToLastPk(int addr, int mrkIdx);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int PP_MarkerPrevPk(int addr, int mrkIdx);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int PP_MarkerNextPk(int addr, int mrkIdx);

        
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int PP_SetMeasurementThreshold(int addr, double measThreshold_dBm);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int PP_GetMeasurementThreshold(int addr, ref double measThreshold_dBm);

        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SensorCnt();                                                 
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SensorList(ref SDByte sd, int cnt);                           
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetAddress_SN(string sn);                                     
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetAddress_Idx(int addr);                                      
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetAddress_SN(string sn, int addr);                           
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetAddress_Idx(int idx, int addr);                            
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_ChangeAddress(int currentAddr, int newAddr);                  

        // ADDRESS CONFLICTS
        // ------------------------------
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_AddressConflictExists();                                        
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_WillAddressConflict(int addr);                                  

        // MODEL NUMBER
        // ------------------------------
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetModelNumber_SN(string sn, ref MODEL_NUMBER modelNumber);     
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetModelNumber_Idx(int idx, ref MODEL_NUMBER modelNumber);      
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetModelNumber_Addr(int addr, ref MODEL_NUMBER modelNumber);    

        // QUERY ABOUT SENSOR
        // ------------------------------
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_IsSensorConnected_SN(string sn);                                
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_IsSensorConnected_Addr(int addr);                               

        // SERIAL NUMBER
        // ------------------------------
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetSerNo_Idx(int idx, ref byte sn);                             
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetSerNo_Addr(int address, ref byte sn);                        

        // INDEX
        // ------------------------------
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetIndex_SN(string sn);                                         
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetIndex_Addr(int addr);                                        

        // BLINK LED
        // ------------------------------
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_BlinkLED_SN(string sn);                                         
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_BlinkLED_Idx(int idx);                                          
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_BlinkLED_Addr(int addr);                                        

        // INITIALIZE SENSOR
        // ------------------------------
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_InitializeSensor_SN(string sn);                                 
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_InitializeSensor_Idx(int idx);                                  
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_InitializeSensor_Addr(int addr);                                

        // MEASUREMENTS
        // ------------------------------
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_MeasureCW(int addr, ref double CW);                             
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_MeasurePulse(int addr, ref double pulse, ref double peak, ref double average, ref double dutyCycle);    
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_MeasureCW_PF(int addr, ref double CW, ref PASS_FAIL_RESULT pf);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_MeasurePulse_PF(int addr, ref double pulse, ref double peak, ref double average, ref double dutyCycle, ref PASS_FAIL_RESULT pf);

        // FREQUENCY (FOR CORRECTION)
        // ------------------------------
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetFrequency(int addr, double value);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetFrequency(int addr, ref double value);

        // AVERAGING
        // ------------------------------
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetAverages(int addr, ref int value);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetAverages(int addr, int value);

        // PULSE MEAUREMENT CRITERIA
        // ------------------------------
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetAutoPulseEnabled(int addr, FEATURE_STATE state);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetAutoPulseEnabled(int addr, ref FEATURE_STATE state);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetPulseCriteria(int addr, double val);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetPulseCriteria(int addr, ref double val);

        // OFFSET
        // ------------------------------
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetOffsetEnabled(int addr, FEATURE_STATE state);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetOffsetEnabled(int addr, ref FEATURE_STATE state);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetOffset(int addr, double val);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetOffset(int addr, ref double val);

        // Frequency Response
        // ------------------------------
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetResponse(int addr, ref ResponsePoints pts, int numPts);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetResponse(int addr, ref ResponsePoints pts, ref int numPts);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetResponseEnabled(int addr, FEATURE_STATE st);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetResponseEnabled(int addr, ref FEATURE_STATE st);


        // DUTY CYCLE
        // ------------------------------
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetDutyCycleEnabled(int addr, FEATURE_STATE state);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetDutyCycleEnabled(int addr, ref FEATURE_STATE state);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetDutyCyclePerCent(int addr, double val);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetDutyCyclePerCent(int addr, ref double val);

        // UNITS
        // ------------------------------
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetMeasurementPowerUnits(int addr, PWR_UNITS units);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetMeasurementPowerUnits(int addr, ref PWR_UNITS units);

        // SET/GET MEASUREMENT REFERENCES
        // ------------------------------
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetCWReference(int addr, double Ref, PWR_UNITS units);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetPulseReference(int addr, double pulseRef, double peakRef, double averageRef, double dutyCycleRef, PWR_UNITS units);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetCWReference(int addr, ref double relRef, ref PWR_UNITS units);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetPulseReference(int addr, ref double pulseRef, ref double peakRef, ref double averageRef, ref double dutyCycleRef, ref PWR_UNITS units);

        // SET/GET ANTI-ALIASING
        // ------------------------------
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetAntiAliasingEnabled(int addr, FEATURE_STATE st);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetAntiAliasingEnabled(int addr, ref FEATURE_STATE st);

        // SET/GET TTL TRIGGER IN
        // ------------------------------
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetTTLTriggerInEnabled(int addr, FEATURE_STATE st);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetTTLTriggerInInverted(int addr, FEATURE_STATE st);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetTTLTriggerInTimeOut(int addr, int timeOut);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetTTLTriggerInEnabled(int addr, ref FEATURE_STATE st);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetTTLTriggerInInverted(int addr, ref FEATURE_STATE st);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetTTLTriggerInTimeOut(int addr, ref int timeOut);

        // SET/GET TTL TRIGGER OUT
        // ------------------------------
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetTTLTriggerOutEnabled(int addr, FEATURE_STATE st);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetTTLTriggerOutInverted(int addr, FEATURE_STATE st);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetTTLTriggerOutEnabled(int addr, ref FEATURE_STATE st);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetTTLTriggerOutInverted(int addr, ref FEATURE_STATE st);

        // SET/GET RECORDER OUTPUT
        // ------------------------------
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetRecorderOutSetup(int addr, double val_0_V, double val_1_V, PWR_UNITS units);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetRecorderOutSetup(int addr, ref double val_0_V, ref double val_1_V, ref PWR_UNITS units);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetRecorderOutEnabled(int addr, FEATURE_STATE st);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetRecorderOutEnabled(int addr, ref FEATURE_STATE st);

        // SET/GET LIMITS
        // ------------------------------
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetLimitEnabled(int addr, LIMIT_STYLE lmtStyle);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetSingleSidedLimit(int addr, double val, PWR_UNITS units, SS_RULE passFail);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetDoubleSidedLimit(int addr, double lowerVal, double upperVal, PWR_UNITS units, DS_RULE passFail);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetLimitEnabled(int addr, ref LIMIT_STYLE lmtStyle);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetSingleSidedLimit(int addr, ref double val, ref PWR_UNITS units, ref SS_RULE passFail);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetDoubleSidedLimit(int addr, ref double lowerVal, ref double upperVal, ref PWR_UNITS units, ref DS_RULE passFail);

        // SET/GET OPTIONS & DATES
        // ------------------------------
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetCalDueDate(string sn, int year, int month, int day);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetCalDueDate(string sn, ref int year, ref int month, ref int day);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetCalOptExpDate(string sn, ref int year, ref int month, ref int day);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetWtyOptExpDate(string sn, ref int year, ref int month, ref int day);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetConnectorOption(string sn, ref CONN_TYPES val);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetCalAndWtyOption(string sn, ref FEATURE_STATE optVal);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetRecorderOutOption(string sn, ref FEATURE_STATE optVal);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetBestMatchOpt(string sn, ref FEATURE_STATE optVal);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetTriggerOpt(string sn, ref FEATURE_STATE optVal);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_GetFilterOpt(string sn, ref FEATURE_STATE optVal);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_Store(int addr, int regIdx);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_Recall(int addr, int regIdx);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_ResetCurrentState(int addr);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_ResetRegStates(int addr);
    }
}
