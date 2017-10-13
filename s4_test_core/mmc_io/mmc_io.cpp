//
// mmc_io.cpp : Defines the exported functions for the DLL application.
//
#include "stdafx.h"

#define DllExport extern "C" __declspec(dllexport) 
#define dump_buffersize_megs 16
#define dump_buffersize (dump_buffersize_megs * 1024 * 1024)
#define dump_workingsetsize ((dump_buffersize_megs + 1) * 1024 * 1024)
#define max_bytes_returned 512

static char _lastError[max_bytes_returned];
static HANDLE hdevice;
//DWORD bytes_to_transfer, byte_count;
static OVERLAPPED overlapped;
static BYTE * buffer;
static GET_LENGTH_INFORMATION source_disklength;
static DISK_GEOMETRY source_diskgeometry;
static LARGE_INTEGER offset;

DllExport char *GetMmcStatus()
{
	ULONG ulSize = (ULONG)strlen(_lastError) + (ULONG)sizeof(char);
	char* pszReturn = NULL;

	pszReturn = (char*)::CoTaskMemAlloc(ulSize);
	// Copy the contents of szSampleString
	// to the memory pointed to by pszReturn.
	strcpy_s(pszReturn, ulSize, _lastError);
	// Return pszReturn.
	return pszReturn;
}

/*
	Open specified physical MMC device
	On success, *hDevice is the MMC device handle.
	Returns: 0 on success, else Windows error code
*/
DllExport int OpenMmc(const char *deviceName, HANDLE *hDevice)
{
	DWORD err;
	DWORD byte_count;

	if (!SetProcessWorkingSetSize(GetCurrentProcess(), dump_workingsetsize, dump_workingsetsize))
	{
		err = GetLastError();
		_snprintf_s(_lastError, max_bytes_returned, "Error %u trying to expand working set.", err);
		return err;
	}

	buffer = (BYTE *)VirtualAlloc(NULL, dump_buffersize, MEM_COMMIT, PAGE_READWRITE);
	if (buffer == NULL)
	{
		err = GetLastError();
		_snprintf_s(_lastError, max_bytes_returned, "Error %u trying to allocate buffer.", err);
		return err;
	}

	if (!VirtualLock(buffer, dump_buffersize))
	{
		err = GetLastError();
		_snprintf_s(_lastError, max_bytes_returned, "Error %u trying to lock buffer.", err);
		return err;
	}

	hdevice = CreateFile
	(
		deviceName,
		GENERIC_READ | GENERIC_WRITE,
		0,
		NULL,
		OPEN_EXISTING,
		FILE_FLAG_NO_BUFFERING,
		NULL
	);
	if (hdevice == INVALID_HANDLE_VALUE) {
		err = GetLastError();
		_snprintf_s(_lastError, max_bytes_returned, "Error %u opening input device.", err);
		return err;
	}

	if (!DeviceIoControl
	(
		hdevice,
		FSCTL_LOCK_VOLUME,
		NULL,
		0,
		NULL,
		0,
		&byte_count,
		NULL
	))
	{
		err = GetLastError();
		_snprintf_s(_lastError, max_bytes_returned, "Error %u locking input volume.", err);
		return err;
	}

	if (!DeviceIoControl
	(
		hdevice,
		IOCTL_DISK_GET_DRIVE_GEOMETRY,
		NULL,
		0,
		&source_diskgeometry,
		sizeof(source_diskgeometry),
		&byte_count,
		NULL
	))
	{
		err = GetLastError();
		_snprintf_s(_lastError, max_bytes_returned, "Error %u getting device geometry.", err);
		return err;
	}

	switch (source_diskgeometry.MediaType)
	{
	case Unknown:
	case RemovableMedia:
	case FixedMedia:

		if (!DeviceIoControl
		(
			hdevice,
			IOCTL_DISK_GET_LENGTH_INFO,
			NULL,
			0,
			&source_disklength,
			sizeof(source_disklength),
			&byte_count,
			NULL
		))
		{
			err = GetLastError();
			_snprintf_s(_lastError, max_bytes_returned, "Error %u getting input device length.", err);
			return err;
		}
		_snprintf_s(_lastError, max_bytes_returned, "MMC device has %I64i bytes.", source_disklength.Length.QuadPart);
		break;

	default:

		source_disklength.Length.QuadPart =
			source_diskgeometry.Cylinders.QuadPart *
			source_diskgeometry.TracksPerCylinder *
			source_diskgeometry.SectorsPerTrack *
			source_diskgeometry.BytesPerSector;

		_snprintf_s(_lastError, max_bytes_returned, "Input device appears to be a floppy disk. May be incomplete copy");
		//fprintf(stderr,
		//	"\n"
		//	"Input device appears to be a floppy disk.  WARNING: if this is not a\n"
		//	"floppy disk the calculated size will probably be incorrect, resulting\n"
		//	"in an incomplete copy.\n"
		//	"\n"
		//	"Input disk has %I64i bytes.\n"
		//	"\n",
		//	source_disklength.Length.QuadPart);

		break;
	}
	*hDevice = hdevice;
	return 0;;
}

/*
Close device

Returns: 0 on success, else Windows error code
*/
DllExport int CloseMmc(HANDLE hDevice)
{
	BOOL status = CloseHandle(hDevice);
	if (status)
	{
		if((status = VirtualUnlock(buffer, dump_buffersize)))
			status = VirtualFree(buffer, dump_buffersize, MEM_COMMIT);
	}
	return status == FALSE ? 0 : 1;
}

/*
	Write data to device, 512 byte array always(for now)

	Returns: 0 on success, else Windows error code
*/
DllExport int WriteMmc(HANDLE hMmc, unsigned char *data, int bytes)
{
	LARGE_INTEGER transfer_length;
	DWORD err;
	DWORD bytes_to_transfer, byte_count;

	if (bytes == 0 || bytes % 512 != 0)
	{
		err = 87;	// INVALID_PARAMETER
		_snprintf_s(_lastError, max_bytes_returned, "Error %u, MMC write must be integral sector size(512).", err);
		return err;
	}

	transfer_length.QuadPart = bytes;

	offset.QuadPart = 0;
	overlapped.hEvent = 0;

	//for (;;)
	//{
		overlapped.Offset = offset.LowPart;
		overlapped.OffsetHigh = offset.HighPart;

		if (transfer_length.QuadPart - offset.QuadPart < dump_buffersize)
		{
			bytes_to_transfer = (DWORD)(transfer_length.QuadPart - offset.QuadPart);
			if (bytes_to_transfer == 0) return 0;
		}
		else
		{
			bytes_to_transfer = dump_buffersize;
		}

		if (!WriteFile(hMmc, data, bytes_to_transfer, NULL, &overlapped))
		{
			err = GetLastError();
			if (err != ERROR_IO_PENDING)
			{
				_snprintf_s(_lastError, max_bytes_returned, "Error %u initiating MMC write.", err);
				return err;
			}
		}

		if (!GetOverlappedResult(hMmc, &overlapped, &byte_count, TRUE))
		{
			err = GetLastError();
			_snprintf_s(_lastError, max_bytes_returned, "Error %u writing to MMC.", err);
			return err;
		}

		if (byte_count != bytes_to_transfer)
		{
			_snprintf_s(_lastError, max_bytes_returned, "Internal error - partial write.");
			//_snprintf_s(_lastError, max_bytes_returned, "bytes_to_transfer = %u; byte_count = %u.\n", bytes_to_transfer, byte_count);
			return ERROR_INVALID_FUNCTION;
		}

		offset.QuadPart += bytes_to_transfer;
	//}

	_snprintf_s(_lastError, max_bytes_returned, "MMC write successfully completed.\n");
	return 0;
}

/*
	Read data from device

	Returns: 0 on success, else Windows error code
*/
DllExport int ReadMmc(int hDevice, unsigned char **data, int bytes)
{
	if (bytes == 0 || bytes % 512 != 0)
	{
		int err = 87;	// INVALID_PARAMETER
		_snprintf_s(_lastError, max_bytes_returned, "Error %u, MMC write must be integral sector size(512).", err);
		return err;
	}

	*data = (unsigned char *)::CoTaskMemAlloc(bytes);

	DWORD err;
	DWORD bytes_to_transfer, byte_count;

	offset.QuadPart = 0;
	overlapped.hEvent = 0;

	//for (;;)
	//{
	overlapped.Offset = offset.LowPart;
	overlapped.OffsetHigh = offset.HighPart;

	//if (source_disklength.Length.QuadPart - offset.QuadPart < dump_buffersize)
	//{
	//	bytes_to_transfer = (DWORD)(source_disklength.Length.QuadPart - offset.QuadPart);
	//	if (bytes_to_transfer == 0)
	//		goto DONE;	// Was break out of for loop
	//}
	//else
	//{
	//	bytes_to_transfer = dump_buffersize;
	//}
	bytes_to_transfer = bytes;
	if (!ReadFile(hdevice, (*data), bytes_to_transfer, NULL, &overlapped))
	{
		err = GetLastError();
		_snprintf_s(_lastError, max_bytes_returned, "Error %u initiating read from input disk.\n", err);
		return err;
	}

	if (!GetOverlappedResult(hdevice, &overlapped, &byte_count, TRUE))
	{
		err = GetLastError();
		_snprintf_s(_lastError, max_bytes_returned, "Error %u reading from input disk.\n", err);
		return err;
	}

	if (byte_count != bytes_to_transfer)
	{
		err = GetLastError();
		_snprintf_s(_lastError, max_bytes_returned, "Internal error - partial read.  Last error code %u.", err);
		//_snprintf_s(_lastError, max_bytes_returned, "bytes_to_transfer = %u; byte_count = %u.\n", bytes_to_transfer, byte_count);
		if (byte_count == 0) return ERROR_INVALID_FUNCTION;
		bytes_to_transfer = byte_count;
	}

	offset.QuadPart += bytes_to_transfer;
	//}
//DONE:
	overlapped.Offset = offset.LowPart;
	overlapped.OffsetHigh = offset.HighPart;

	_snprintf_s(_lastError, max_bytes_returned, "Read MMC successfully completed.");
	return 0;

	//if (byte_count == 0)
	//{
	//	_snprintf_s(_lastError, max_bytes_returned, "Save successfully completed.\n");
	//	return 0;
	//}

	//_snprintf_s(_lastError, max_bytes_returned, "WARNING: the expected amount of data was successfully copied but end of file not detected on input disk.  Read might not be complete.");
	//return ERROR_MORE_DATA;
}

