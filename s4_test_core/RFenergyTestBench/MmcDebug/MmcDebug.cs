
using System;
using System.Runtime.InteropServices;
using Interfaces;

namespace MmcDebug
{
    public class MmcDebug : IMmc
    {
        [DllImport("mmc_io.dll", CallingConvention = CallingConvention.Cdecl, CharSet=CharSet.Ansi)]
        static extern int OpenMmc([MarshalAs(UnmanagedType.LPStr)]string deviceName, ref IntPtr hMmcDevice);

        [DllImport("mmc_io.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        static extern int CloseMmc(IntPtr hDevice);

        [DllImport("mmc_io.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        static extern int WriteMmc(IntPtr hMmc, [MarshalAs(UnmanagedType.LPArray)]byte[] data, int bytes);

        [DllImport("mmc_io.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        static extern int ReadMmc(IntPtr hDevice, [MarshalAs(UnmanagedType.LPArray, SizeParamIndex=2)]ref byte[] data, int bytes);

        [DllImport("mmc_io.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        [return: MarshalAs(UnmanagedType.LPStr)]
        static extern string GetMmcStatus();

        IntPtr _hmmc;
        string _lastStatus;

        public int OpenMmcDevice(string mmcDevice)
        {
            try
            {
                _hmmc = new IntPtr(0);
                int status = OpenMmc(mmcDevice, ref _hmmc);
                _lastStatus = GetMmcStatus();
                return status;
            }
            catch(Exception ex)
            {
                throw new ApplicationException(string.Format("Exception opening MMC device {0}", mmcDevice), ex);
            }
        }

        public int CloseMmcDevice()
        {
            try
            {
                if(_hmmc != null && _hmmc.ToInt32() != 0)
                {
                    int status = CloseMmc(_hmmc);
                    _lastStatus = GetMmcStatus();
                    if (status == 0)
                        _hmmc = new IntPtr(0);
                    return status;
                }
                return 0;
            }
            catch (Exception ex)
            {
                throw new ApplicationException("Exception closing MMC device", ex);
            }
        }

        public int ReadMmcDevice(ref byte[] data)
        {
            try
            {
                if (data == null)
                    data = new byte[1024];
                int status = ReadMmc(_hmmc, ref data, data.Length);
                _lastStatus = GetMmcStatus();
                Array.Copy(data, 512, data, 0, 512);
                return status;
            }
            catch (Exception ex)
            {
                throw new ApplicationException("Exception reading MMC device", ex);
            }
        }

        public int WriteMmcDevice(byte[] opcodes)
        {
            try
            {
                if (opcodes.Length == 0 || opcodes.Length % 512 != 0)
                {
                    _lastStatus = "Opcode block must be integral multiple of 512 bytes.";
                    return 87;  // INVALID_PARAMETER
                }

                int status = WriteMmc(_hmmc, opcodes, opcodes.Length);
                _lastStatus = GetMmcStatus();
                return status;
            }
            catch (Exception ex)
            {
                throw new ApplicationException("Exception writing MMC device", ex);
            }
        }

        public int GetLastMmcStatus(ref string status)
        {
            try
            {
                status = GetMmcStatus();
                return 0;
            }
            catch (Exception ex)
            {
                throw new ApplicationException("Exception getting MMC status", ex);
            }
        }
    }
}
