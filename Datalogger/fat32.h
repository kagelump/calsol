#include "sd-spi.h"
#include "types.h"

#ifndef FAT32_H
#define FAT32_H

static const fs_length_t BLOCK_SIZE = 512;
static const fs_length_t BYTES_PER_SECTOR = 512;
static const uint32_t FAT32_LAST_BLOCK_MIN_BOUND = 0x0FFFFFF8;
static const uint32_t FAT32_LAST_BLOCK_MAX_BOUND = 0x0FFFFFFF;
static const uint32_t FAT32_BAD_CLUSTER = 0x0FFFFFF7;
static const uint32_t FAT32_RESERVED_CLUSTER_MIN_BOUND = 0x0FFFFFF0;
static const uint32_t FAT32_RESERVED_CLUSTER_MAX_BOUND = 0x0FFFFFF6;
static const uint32_t FAT32_FREE_CLUSTER = 0;
static const uint32_t FAT32_VALID_CLUSTER_MIN = 2;
static const uint32_t FAT32_VALID_CLUSTER_MAX = 0x0FFFFFEF;

/**
 * Data structure holding relevant information for a FAT32 directory.
 * When initialized, it should hold all the information necessary to do directory access.
 */
typedef struct {
	fs_addr_t directoryTableBeginCluster;		/// Cluster number of the beginning of the directory table.

	fs_addr_t directoryTableAvailableCluster;	/// Cluster number of the first available entry in the directory table.
	fs_addr_t directoryTableAvailableClusterOffset;	// Cluster offset of the first available entry of the directory table.
	fs_addr_t directoryTableAvailableLBA;		/// LBA of the first available entry in the directory table
} FAT32Directory;

/**
 * Data structure holding relevant information for a FAT32 filesystem.
 * When intiailized, it should hold all the information necessary to do file opens, ...
 * Note that the entire file table should NOT be read - data reads are done on demand.
 */
typedef struct {
	uint16_t bytesPerSector;			/// Bytes in a sector, almost always 512.
	uint8_t sectorsPerCluster;			/// Number of sectors in a cluster.
	uint16_t numberOfReservedSectors;
	uint8_t numberOfFATs;
	uint32_t sectorsPerFAT;
	FAT32Directory rootDirectory;
	uint16_t FS_info_LBA;				/// LBA of the FS Information Sector.

	uint8_t clusterPointerSize;			/// Size, in bytes, of a cluster pointer (FAT entry).

	fs_addr_t Partition_LBA_Begin;		/// LBA where the partition begins
	fs_addr_t FAT_LBA_Begin;			/// LBA where FAT #1 begins.
	fs_addr_t Cluster_LBA_Begin;		/// LBA where the Clusters (holding files and directories) section begins.

	uint32_t numFreeClusters;			/// Number of free clusters, as indicated by the FS Information Sector.
	uint32_t mostRecentCluster;			/// Most recently allocated cluster, as indicated by the FS Information Sector.
	uint8_t fsInfoDirty;				/// Whether FS Information Sector data has been changed and needs to be committed to disk.

	SDCard *card;
} FAT32FS;

/* Data helper functions
 */
inline uint16_t FATDataToInt16(uint8_t *data);
inline uint32_t FATDataToInt32(uint8_t *data);
inline uint32_t FATSplitDataToInt32(uint8_t *dataHigh, uint8_t *dataLow);

inline void Int16ToFATData(uint8_t *dest, uint16_t data);
inline void Int32ToFATData(uint8_t *dest, uint32_t data);
inline void Int32ToFATSplitData(uint8_t *dataHigh, uint8_t *dataLow, uint32_t data);

/* FAT32 helper functions
 */
inline fs_addr_t GetClusterFATLBA(FAT32FS *fs, uint32_t clusterNumber);
inline uint16_t GetClusterFATOffset(FAT32FS *fs, uint32_t clusterNumber);
fs_addr_t GetClusterLBA(FAT32FS *fs, uint32_t clusterNumber);
inline uint32_t GetNextCluster(FAT32FS *fs, uint32_t clusterNumber);
inline uint16_t GetClustersPerBlock(FAT32FS *fs);

/* FAT32 filesystem functions
 */
int8_t FAT32_Initialize(FAT32FS *fs, SDCard *card);

#endif
