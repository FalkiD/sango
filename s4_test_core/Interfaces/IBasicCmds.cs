/// <summary>
/// Basic RFE API commands
/// </summary>
namespace Interfaces
{
    interface IBasicCmds
    {
        int RFE_CapabilityGet(ref string capabilities);
        int RFE_FrequencyModeSet(bool multiFrequencyMode);
        int RFE_FrequencyModeGet(ref bool multiFrequencyMode);
        int RFE_FrequencyChannelSet(uint channel, uint frequency);
        int RFE_FrequencyChannelGet(uint channel, ref uint frequency);
        int RFE_PhaseChannelSet(uint channel, uint phase);
        int RFE_PhaseChannelGet(uint channel, ref uint phase);
        int RFE_MagnitudeChannelSet(uint channel, uint magnitude);
        int RFE_MagnitudeChannelGet(uint channel, ref uint magnitude);
        int RFE_AttenuationChannelSet(uint channel, uint attenuation);
        int RFE_AttenuationChannelGet(uint channel, ref uint attenuation);
        int RFE_AttenuationSythesizerSet(uint channel, uint attenuation);
        int RFE_PWMChannelSet(uint channel, uint dutyCycle);
        int RFE_PWMChannelGet(uint channel, ref uint dutyCycle);
        int RFE_EnableChannelSet(uint channel, bool enable);
        int RFE_EnableChannelGet(uint channel, ref bool enable);
        int RFE_EnablePowerSet(uint channel, bool enable);
        int RFE_EnablePowerGet(uint channel, ref bool enable);

        /// <summary>
        /// fwdPower array size indicates the number
        /// of readings to return.
        /// </summary>
        /// <param name="channel"></param>
        /// <param name="results"></param>
        /// <returns></returns>
        int RFE_PowerForwardRead(uint channel, ref int[] fwdPower);

        /// <summary>
        /// reflResults array size indicates the number
        /// of readings to return.
        /// </summary>
        /// <param name="channel"></param>
        /// <param name="results"></param>
        /// <returns></returns>
        int RFE_PowerReverseRead(uint channel, ref int[] reflPower);

        /// <summary>
        /// size of fwdI determines the number of readings returned.
        /// Method will size all other arrays teh same as fwdI.
        /// </summary>
        /// <param name="channel"></param>
        /// <param name="fwdI"></param>
        /// <param name="fwdQ"></param>
        /// <param name="reflI"></param>
        /// <param name="reflQ"></param>
        /// <returns></returns>
        int RFE_IQRead(uint channel, ref int[] fwdI, ref int[] fwdQ, ref int[] reflI, ref int[] reflQ);

        int RFE_SSBTemperatureRead(uint channel, ref int[] temperatures);

        int RFE_HPATemperatureRead(uint channel, ref int[] temparetures);
    }
}
