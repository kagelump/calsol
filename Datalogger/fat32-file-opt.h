#include "sd-spi.h"
#include "types.h"

#include "fat32.h"

#ifndef FAT32_FILE_OPT_H
#define FAT32_FILE_OPT_H

#define FAT32_NUM_DATA_BUFFERS	2
#define FAT32_OVERFLOW_BUFFER_SIZE	4096

#define FAT32_NUM_WRITE_BLOCKS	32

typedef enum {
	FILE_OP_None,
	FILE_OP_WritingDataIdle,
	FILE_OP_WritingData,
	FILE_OP_WritingDirectoryTable,
	FILE_OP_WritingFAT,
	FILE_OP_WritingFSInformation,
	FILE_OP_SingleBlockWriteTerminate,
	FILE_OP_MultipleBlockWriteTerminate
} FileOperation;

/**
 * Holds data for files specific to optimizing large contigious writes.
 */
typedef struct {
	char name[8];							/// 8.3 File name - limited to 8 characters, note that LFN is not supported.
	char ext[3];							/// 8.3 Extension - limited to 3 characters

	FAT32FS *fs;							/// Filesystem object for this file.

	/* Directory entry variables
	 */
	uint8_t directoryTableBlockData[512];	/// Cache for the directory table block.
	fs_addr_t directoryTableLBA;			/// Block address of the directory table entry containing this file.
	uint16_t directoryTableBlockOffset;		/// Byte offset (from block beginning) of the directory table entry containing this file.
	uint8_t directoryTableDirty;			/// Whether the directoryTableBlock buffer has been changed since it was last written to disk.

	/* File allocation table caches
	 * Note that a dual cache is necessary to acoomocate multiple file streams
	 * in case the previously written next cluster isn't what is expected.
	 */
	uint8_t previousFATData[512];			/// This actually allocates the cache.
	uint8_t *previousFATBlockData;			/// Cache for the FAT block previously written to disk.
	fs_addr_t previousFATLBA;				/// Block address of the previous FAT block
	uint16_t previousFATBlockOffset;		/// Byte offset in previousFATData containing the last cluster entry of the file.
	uint8_t previousFATDirty;				/// Whether the previousFATData buffer has been changed when allocating the next FAT data block.

	uint32_t previousFileSize;				/// File size of the previously allocated clusters.

	uint8_t currentFATData[512];			/// This actually allocates the cache.
	uint8_t *currentFATBlockData;			/// Cache for the FAT block currently being filled.
	fs_addr_t currentFATLBA;				/// Block address of the current FAT block
	uint16_t currentFATBlockOffset;			/// Byte offset in currentFATData containing the last cluster entry of the file.
	uint8_t currentFATAllocated;			/// Whether or not the next block has been allocated.
	uint8_t currentFATDirty;				/// Whether the currentFATData has been written to disk,s

	/* File allocation variables
	 */
	uint32_t startCluster;					/// Starting cluster number of the file.
	fs_size_t position;						/// Size of the data committed to disk.
	fs_size_t size;							/// Allocated size of the file, in bytes. This should be consistent with the number of allocated clusters
											/// and should be committed to disk when the clusters are alloated.

	uint32_t currentCluster;				/// Cluster number of the cluster containing the current byte position.
	fs_addr_t currentLBA;					/// Block number of the next block to be written.
	uint8_t currentClusterLBAOffset;		/// Block offset from the beginning of the current cluster.
	uint32_t currentClusterEnd;				/// Cluster number of the last cluster allocated.

	uint32_t nextClusterBegin;				/// Cluster number of the beginning of the next block allocated.
	uint32_t nextClusterEnd;				/// Cluster number of the end of the next block allocated.

	/* File operation state
	 */
	FileOperation currentOperation;			/// Current file operation in progress
	FileOperation nextOperation;			/// Next file operation (only valid if current operation is nothing or terminating)

	/* Data buffering variables
	 */
	uint8_t *dataBuffer[FAT32_NUM_DATA_BUFFERS];	/// Dual DMA buffers holding data to be written to disk.
	uint8_t dataBufferWrite;				/// The next DMA buffer to be written to disk.
	uint8_t dataBufferFill;					/// The data buffer being filled with user data, or 255 if the RAM overflow buffer is being used.
	uint8_t dataBufferNumFilled;			/// Number of completely filled data buffers.
	uint16_t dataBufferPos;					/// Next byte in the data buffer that is to be filled with user data.

	uint8_t overflowBuffer[FAT32_OVERFLOW_BUFFER_SIZE];			/// Buffer for storing data when the primary dual buffer overflows.
	uint16_t overflowBufferBegin;			/// Index of the first byte in the overflow buffer.
	uint16_t overflowBufferEnd;				/// Index of the next free byte in the overflow buffer
	uint16_t overflowBufferSize;			/// Number of bytes in the overflow buffer.

	uint8_t *fsBuffer;						/// DMA buffer holding filesysten information to be written to disk.
} FAT32FileOpt;

/* FAT32 optimized file helpers
 */
int8_t FAT32_InitializeFileFAT(FAT32FileOpt *file);
void FAT32_SwitchNextBlock(FAT32FileOpt *file);
uint16_t FAT32_AllocateFATBlock(FAT32FileOpt *file);
void FAT32_FillCurrentFATBlock(FAT32FileOpt *file);
void FAT32_FillPreviousFATBlock(FAT32FileOpt *file);
void FAT32_UpdateDirectoryTableEntry(FAT32FileOpt *file);
void FAT32_FillDirectoryTableBlock(FAT32FileOpt *file);

void FAT32_WriteOverflowBuffer(FAT32FileOpt *file, uint8_t *data, fs_length_t length);
fs_length_t FAT32_WriteBuffer(FAT32FileOpt *file, uint8_t *data, fs_length_t length);

/* FAT32 optimized file functions
 */
int8_t FAT32_CreateFileOpt(FAT32FS *fs, FAT32Directory *dir, FAT32FileOpt *fileOpt, char *name, char *ext);

fs_length_t FAT32_WriteFileOpt(FAT32FileOpt *fileopt, uint8_t *data, fs_length_t dataLen);

#endif
