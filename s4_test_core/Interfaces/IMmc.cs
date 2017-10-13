
namespace Interfaces
{
    public interface IMmc
    {
        /// <summary>
        /// Open named physical MMC device
        /// </summary>
        /// <param name="mmcDevice">Physical device name of MMC device</param>
        /// <returns>0 on success, else Windows error code</returns>
        int OpenMmcDevice(string mmcDevice);

        /// <summary>
        /// Close peviously opened physical MMC device
        /// </summary>
        /// <returns>0 on success, else Windows error code</returns>
        int CloseMmcDevice();

        /// <summary>
        /// Write an opcode block to MMC
        /// Returns status byte from MMC write
        /// </summary>
        /// <param name="opcodes"></param>
        /// <returns></returns>
        int WriteMmcDevice(byte[] opcodes);

        /// <summary>
        /// Read data from MMC
        /// Returns status bye from MMC read
        /// </summary>
        /// <param name="data"></param>
        /// <returns></returns>
        int ReadMmcDevice(ref byte[] data);
    }
}
