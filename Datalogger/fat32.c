/*
 * File:   fat32.c
 * Author: Ducky
 *
 * Created on February 26, 2011, 3:21 PM
 */
#include "sd-spi.h"
#include <string.h>

#include "fat32-debug.h"
#include "fat32.h"

/**
 * Converts a 2-byte-long piece of data from the FAT boot sector into a 16-bit integer.
 * @param[in] data Data source, 2 bytes long starting at this pointer.
 */
inline uint16_t FATDataToInt16(uint8_t *data) {
	uint16_t store;
	uint8_t *storeByte = (uint8_t*)&store;

	storeByte[0] = data[0];
	storeByte[1] = data[1];

	return store;
}

/**
 * Converts a 4-byte-long piece of data from the FAT boot sector into a 32-bit integer.
 * @param[in] data Data source, 4 bytes long starting at this pointer.
 */
inline uint32_t FATDataToInt32(uint8_t *data) {
	uint32_t store;
	uint8_t *storeByte = (uint8_t*)&store;

	storeByte[0] = data[0];
	storeByte[1] = data[1];
	storeByte[2] = data[2];
	storeByte[3] = data[3];

	return store;
}

/**
 * Converts a non-contiguous 4-byte-long piece of data from the FAT boot sector into a 32-bit integer.
 * @param[in] dataHigh High part (MSB) of data source, 2 bytes starting at this pointer.
 * @param[in] dataLow Low part (LSB) of data source, 2 bytes starting at this pointer.
 */
inline uint32_t FATSplitDataToInt32(uint8_t *dataHigh, uint8_t *dataLow) {
	uint32_t store;
	uint8_t *storeByte = (uint8_t*)&store;

	storeByte[0] = dataLow[0];
	storeByte[1] = dataLow[1];
	storeByte[2] = dataHigh[0];
	storeByte[3] = dataHigh[1];

	return store;
}

/**
 * Converts a 16-bit integer to a 2-byte-long little-endian format data for FAT.
 * @param[out] dest Data destination, 2 bytes long starting at this pointer.
 * @param[in] data 16-bit integer to covert.
 */
inline void Int16ToFATData(uint8_t *dest, uint16_t data) {
	uint8_t *dataByte = (uint8_t*)&data;
	dest[0] = dataByte[0];
	dest[1] = dataByte[1];
}

/**
 * Converts a 32-bit integer to a 4-byte-long little-endian format data for FAT.
 * @param[out] dest Data destination, 4 bytes long starting at this pointer.
 * @param[in] data 32-bit integer to covert.
 */
inline void Int32ToFATData(uint8_t *dest, uint32_t data) {
	uint8_t *dataByte = (uint8_t*)&data;
	dest[0] = dataByte[0];
	dest[1] = dataByte[1];
	dest[2] = dataByte[2];
	dest[3] = dataByte[3];
}

/**
 * Converts a 32-bit integer to a non-contiguous 4-byte-long little-endian format data for FAT.
 * @param[out] destHigh High part (MSB) of the data destination, 2 bytes long starting at this pointer.
 * @param[out] destLow Low part (LSB) of the data destination, 2 bytes long starting at this pointer.
 * @param[in] data 32-bit integer to covert.
 */
inline void Int32ToFATSplitData(uint8_t *destHigh, uint8_t *destLow, uint32_t data) {
	uint8_t *dataByte = (uint8_t*)&data;
	destLow[0] = dataByte[0];
	destLow[1] = dataByte[1];
	destHigh[0] = dataByte[2];
	destHigh[1] = dataByte[3];
}

/**
 * @return The LBA (block address) of the block of the FAT containing the cluster pointer.
 */
inline fs_addr_t GetClusterFATLBA(FAT32FS *fs, uint32_t clusterNumber) {
	return fs->FAT_LBA_Begin + (clusterNumber / GetClustersPerBlock(fs));
}

/**
 * @return The byte offset from the block beginning containing the cluster number in the FAT.
 */
inline uint16_t GetClusterFATOffset(FAT32FS *fs, uint32_t clusterNumber) {
	return (clusterNumber % GetClustersPerBlock(fs)) * fs->clusterPointerSize;
}

/**
 * @return The LBA (block address) of the first block of cluster.
 */
inline fs_addr_t GetClusterLBA(FAT32FS *fs, uint32_t clusterNumber) {
	return fs->Cluster_LBA_Begin + (clusterNumber - 2) * fs->sectorsPerCluster;
}

/**
 * @return The number of cluster pointers in a single block.
 */
inline uint16_t GetClustersPerBlock(FAT32FS *fs) {
	return BLOCK_SIZE / fs->clusterPointerSize;
}

/**
 * Finds the next cluster number in the FAT.
 * @param fs Filesystem struct
 * @param clusterNumber currentClusterNumber
 * @retval next cluster
 * @retval 0xF0000000 No more clusters after this.
 * @retval 0xFFFFFFFF Unexpected cluster
 * @retval 0xFFFFFFFE Error reading SD card -- not reading correct number of bytes
 */
uint32_t getNextCluster(FAT32FS *fs, uint32_t clusterNumber) {
	fs_addr_t addr = GetClusterFATLBA(fs, clusterNumber);		// LBA of the block containing this FAT entry
	uint16_t offset = GetClusterFATOffset(fs, clusterNumber);	// FAT entry in block that holds this entry
	uint8_t buffer[BLOCK_SIZE];

	DBG_DATA_printf("Read FAT at LBA = 0x%08lx (cluster=0x%08lx, offset=%u)", addr, clusterNumber, offset)

	if (BLOCK_SIZE != SD_SPI_ReadSingleBlock(fs->card, addr, buffer)) {
		return 0xFFFFFFFE;			// Sanity check: Not reading the correct number of bytes
	}

	uint32_t number = FATDataToInt32(buffer+offset);
	if (FAT32_LAST_BLOCK_MIN_BOUND <= number &&
		FAT32_LAST_BLOCK_MAX_BOUND >= number) {
		return 0xF0000000;
	}
	else if (FAT32_VALID_CLUSTER_MIN <= number &&
			 FAT32_VALID_CLUSTER_MAX >= number) {
		return number;
	}
	else {
		return 0xFFFFFFFF;
	}
}

/**
 * Initializes the FAT32 file system struct.
 * Loads any important information about the file system into the struct.
 * After this function returns successfully, it should be possible to create, read, and find files.
 * This does NOT read the entire file table into memory - that is accessed on demand.
 *
 * @param[in] card SD Card structure.
 * @param[out] fs Filesystem struct to initialize.
 * @return 1 on success, negative on failure (todo: describe error codes below)
 * @retval -1 Failure: SD Card read error
 * @retval -2 Failure: Records did not contain the expected signature (possibly invalid filesystem)
 * @retval -3 Failure: Bytes per sector was not read as 512
 * @retval -4 Failure: Not a supported filesystem
 */
int8_t FAT32_Initialize(FAT32FS *fs, SDCard *card) {
	uint8_t buffer[BLOCK_SIZE] __attribute__((aligned(4)));
	if (BLOCK_SIZE != SD_SPI_ReadSingleBlock(card, 0, buffer)) {
		DBG_ERR_printf("Block read failed.");
		return -1;			// Sanity check: Not reading the correct number of bytes
	}
	if (buffer[510] != 0x55 ||  buffer[511] != 0xAA) {
		DBG_ERR_printf("Sector 0 has bad signature.");
		return -2;			// Sanity check: Boot records should end in 0xAA55 (little endian)
	}
	fs->card = card;
	fs->Partition_LBA_Begin = 0;
	uint8_t isBootSector = 1;

	/*
	 * Huge check of whether this is a Master Boot Record
	 * or a Boot Sector (Volume ID).
	 */
	if (!((buffer[0] == 0xEB && buffer[2] == 0x90) || buffer[0] == 0xE9)) {
		DBG_DATA_printf("Sector 0 is MBR (invalid jump instructions).");
		isBootSector = 0;
	} else if (!((buffer[13] != 0) && ((buffer[13] & (~buffer[13] + 1)) == buffer[13]))) {
		DBG_DATA_printf("Sector 0 is MBR (Sectors per cluster cannot be a non-power of 2).");
		isBootSector = 0;
	} else if (buffer[16] != 2) {
		if (buffer[16] == 0) {
			DBG_DATA_printf("Sector 0 is MBR (Number of FATs cannot be 0).");
			isBootSector = 0;
		} else {
			DBG_printf("Warning: Number of FATs not 2.");
		}
	} else {
		DBG_DATA_printf("Sector 0 is FAT Boot Table.");
	}

	if (!isBootSector) {		// Must be MBR, so we should find the Boot Sector
		fs->Partition_LBA_Begin = FATDataToInt32(buffer+446+8);
		DBG_DATA_printf("FAT Boot Sector LBA = 0x%08lx", fs->Partition_LBA_Begin)

		if (BLOCK_SIZE != SD_SPI_ReadSingleBlock(card, fs->Partition_LBA_Begin, buffer)) {
			return -1;
		}
		if (buffer[510] != 0x55 || buffer[511] != 0xAA) {
			DBG_ERR_printf("FAT Boot Sector has bad signature.");
			return -2;
		}
	}

	DBG_DATA_printf("FAT Boot Sector LBA = 0x%08lx", fs->Partition_LBA_Begin);

	if (buffer[0x42] == 0x29 && (buffer[0x40] == 0x00 || buffer[0x40] == 0x80)) {
		DBG_DATA_printf("Detected FAT32 filesystem.");
		fs->clusterPointerSize = 4;
	} else if (buffer[0x26] == 0x29 && (buffer[0x24] == 0x00 || buffer[0x24] == 0x80)) {
		DBG_ERR_printf("Detected FAT12/16 filesystem.");
		DBG_ERR_printf("Unsupported filesystem.");
		return -4;
	} else {
		DBG_ERR_printf("Detected unknown filesystem.");
		DBG_ERR_printf("Unsupported filesystem.");
		return -4;
	}

	fs->bytesPerSector = buffer[11] + ((uint16_t) buffer[12]) << 8; 

	if (fs->bytesPerSector != 512) {
		DBG_ERR_printf("Bytes per sector is not 512.");
		return -3;
	}

	fs->sectorsPerCluster = buffer[13];
	fs->numberOfReservedSectors = FATDataToInt16(buffer+14);
	fs->numberOfFATs = buffer[16];

	fs->sectorsPerFAT = FATDataToInt32(buffer+36);
	fs->rootDirectory.directoryTableBeginCluster = FATDataToInt32(buffer+44);
	fs->FS_info_LBA = FATDataToInt16(buffer+0x30) + fs->Partition_LBA_Begin;

	fs->FAT_LBA_Begin = fs->Partition_LBA_Begin + fs->numberOfReservedSectors;
	fs->Cluster_LBA_Begin = fs->FAT_LBA_Begin + fs->numberOfFATs * fs->sectorsPerFAT;

	fs->rootDirectory.directoryTableAvailableCluster = fs->rootDirectory.directoryTableBeginCluster;
	fs->rootDirectory.directoryTableAvailableLBA = GetClusterLBA(fs, fs->rootDirectory.directoryTableAvailableCluster);
	fs->rootDirectory.directoryTableAvailableClusterOffset = 0;

	// Read FS Information Sector
	if (BLOCK_SIZE != SD_SPI_ReadSingleBlock(card, fs->FS_info_LBA, buffer)) {
		return -1;
	}

	DBG_DATA_printf("FS Information Sector LBA = 0x%08lx", fs->FS_info_LBA);

	// Check for information sector signatures
	if (buffer[0x00] != 'R' || buffer[0x01] != 'R' || buffer[0x02] != 'a' || buffer[0x03] != 'A'
			|| buffer[0x1e4] != 'r' || buffer[0x1e5] != 'r' || buffer[0x1e6] != 'A' || buffer[0x1e7] != 'a'
			|| buffer[0x1fe] != 0x55 || buffer[0x1ff] != 0xAA) {
		if (buffer[0x1e6] == 'a' && buffer[0x1e7] == 'A') {
			DBG_printf("Warning: FS Information Sector has 'rraA' signature.");
		} else {
			DBG_ERR_printf("FS Information Sector has bad signature.");
			return -2;
		}
	}
	// Parse FS Information Sector
	fs->numFreeClusters = FATDataToInt32(buffer+0x1e8);
	fs->mostRecentCluster = FATDataToInt32(buffer+0x1ec);

	DBG_DATA_printf("Bytes Per Sector = %u, Sectors Per Cluster = %u", fs->bytesPerSector, fs->sectorsPerCluster);
	DBG_DATA_printf("Number of Reserved Sectors = %u", fs->numberOfReservedSectors);
	DBG_DATA_printf("Number of FATs = %u, Sectors Per Fat = %u", fs->numberOfFATs, fs->sectorsPerFAT);
	DBG_DATA_printf("Root Cluster Number = 0x%08lx", fs->rootDirectory.directoryTableBeginCluster);

	DBG_DATA_printf("Partition LBA = 0x%08lx, FAT LBA = 0x%08lx, Cluster LBA = 0x%08lx",
			fs->Partition_LBA_Begin, fs->FAT_LBA_Begin, fs->Cluster_LBA_Begin)

	DBG_DATA_printf("Number of Free Clusters = %lu", fs->numFreeClusters);
	DBG_DATA_printf("Most Recently Allocated Cluster = 0x%08lx", fs->mostRecentCluster);

	return 1;
}
