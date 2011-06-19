#include "sd-spi.h"
#include "types.h"

#include "fat32.h"

#ifndef FAT32_FILE_H
#define FAT32_FILE_H

/**
 * Data structure holding relevant information for a FAT32 file.
 * When initialized, it should hold all the information necessary to do file reads / writes.
 * This data structure only holds pointers - data is not cached here.
 */
typedef struct {
	char name[8];		//!< File name - limited to 8 characters, note that LFN is not supported.
	char ext[3];		//!< Extension - limited to 3 characters

	fs_addr_t directoryTableBlock;		/// Block address of the directory table entry containing this file.
	uint8_t directoryTableOffset;		/// Entry number of the block contaiing this entry. Multiply by 32 to get the byte offset.

	uint32_t startClusterNumber;		/// Starting cluster number of the file.
	fs_size_t size;						/// Size of the file, in bytes, as indicated by the Directory Table.

	uint32_t currentClusterNumber;		/// Current cluster number containing the byte-position
	fs_size_t currentPosition;			/// Current byte-position within the file
} FAT32File;

/* FAT32 file helper functions
 */
void FATCreateDirectoryTableEntry(uint8_t *buffer, char *name, char *ext);

/* FAT32 file functions
 */
int8_t FAT32_CreateFile(FAT32FS *fs, FAT32Directory *dir, FAT32File *file, char *name, char *ext);
int8_t FAT32_OpenFile(FAT32FS *fs, FAT32Directory *dir, FAT32File *file, char *name, char *ext);
int8_t FAT32_CloseFile(FAT32File *file);

#endif
