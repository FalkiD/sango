using System;
using System.Collections.Generic;
using System.Text;

namespace LadyBug_TestHarness
{
    class LB_Proprietary
    {
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetCalOptExpDate(string sn, int pw, int year, int month, int day);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetWtyOptExpDate(string sn, int PW, int lngYear, int lngMonth, int lngDay);        
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetConnectorOption(string sn, int pw, LB_API2_Declarations.CONN_TYPES optVal);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetCalAndWtyOption(string sn, int pw, LB_API2_Declarations.FEATURE_STATE optVal);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetRecorderOutOption(string sn, int pw, LB_API2_Declarations.FEATURE_STATE optVal);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetBestMatchOpt(string sn, int pw, LB_API2_Declarations.FEATURE_STATE optVal);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetTriggerOpt(string sn, int pw, LB_API2_Declarations.FEATURE_STATE optVal);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetFilterOpt(string sn, int pw, LB_API2_Declarations.FEATURE_STATE optVal);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetModelNumber(string SN, int PW, LB_API2_Declarations.MODEL_NUMBER modelNumber);
        [System.Runtime.InteropServices.DllImport("LB_API2.dll")]
        public static extern int LB_SetSerialNumber(int idx, int PW, string SN);
    }
}
