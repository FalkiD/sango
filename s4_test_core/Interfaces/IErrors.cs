/// <summary>
/// Handle errors
/// </summary>
namespace Interfaces
{
    public interface IErrors
    {
        /// <summary>
        /// Returns error description based on error code
        /// returned by firmware
        /// </summary>
        /// <param name="errorCode"></param>
        /// <returns></returns>
        string ErrorDescription(int errorCode);
    }
}
