
namespace Interfaces
{
    /// <summary>
    /// All functions throw ApplicationException on error,
    /// with error description filled-in
    /// </summary>
    public interface IMeter
    {
        void WriteCommand(string scpi);

        void WriteCommand(byte[] data);

        string Read { get; }
    }
}
