/*
 * File:   fat32-file.c
 * Author: Ducky
 *
 * Created on April 25, 2011, 1:06 AM
 */

#include "sd-spi.h"
#include <string.h>

#include "fat32-debug.h"
#include "fat32.h"
#include "fat32-file.h"

/**
 * Fills the 32 bytes starting at /a buffer with the FAT directory table entry
 * for a file with an 8-character name /a name and 3-character extension /ext
 * @param buffer Pointer to the start of the file record to fill.
 * @param name Name of the file, should be a null-terminated string.
 * @param ext Extension of the file, should be a null-terminated string.
 */
void FATCreateDirectoryTableEntry(uint8_t *buffer, char *name, char *ext) {
	uint8_t i = 0;
	for (i=0;i<8;i++) {
		if (name[i] == '\0') {
			break;
		} else {
			buffer[i] = name[i];
		}
	}
	for (;i<8;i++) {
		buffer[i] = ' ';
	}

	for (i=0;i<3;i++) {
		if (ext[i] == '\0') {
			break;
		} else {
			buffer[i+8] = ext[i];
		}
	}
	for (;i<3;i++) {
		buffer[i+8] = ' ';
	}

	for (i=0x0b;i<0x20;i++) {
		buffer[i] = 0x00;
	}
}

/**
 * Creates a file - creates the directory entry for a file.
 * After this function returns successfully, it should be possible to write the file
 * starting at the beginning.
 * No checks are done against duplicate file names, and clusters are not allocated.
 *
 * @param[in] fs Filesystem structure.
 * @param[in] dir Directory structure.
 * @param[out] file Output file structure.
 * @param[in] name File name, up to 8 characters.
 * @param[in] ext File extension, up to 3 characters.
 * @retval 1 Success
 * @retval -1 Error creating file
 * @retval -2 SD Card Error
 */
int8_t FAT32_CreateFile(FAT32FS *fs, FAT32Directory *dir, FAT32File *file, char *name, char *ext) {
	uint32_t currentCluster = dir->directoryTableAvailableCluster;
	fs_addr_t currentLBA = dir->directoryTableAvailableLBA;
	uint8_t clusterOffset = dir->directoryTableAvailableClusterOffset;	// block number within the cluster

	uint8_t buffer[BLOCK_SIZE];
	fs_length_t iii = 0;

	DBG_DATA_printf("Starting cluster = 0x%08lx", currentCluster);

	// Search for an empty file
	while (1) {
		if (BLOCK_SIZE != SD_SPI_ReadSingleBlock(fs->card, currentLBA, buffer)) {
			DBG_printf("Error creating file (SD Read error on LBA = 0x%08lx).", currentLBA);
			return -2;			// Sanity check: Not reading the correct number of bytes
		}
		DBG_DATA_printf("Read Directory Table LBA = 0x%08lx", currentLBA)

		// Search Directory Table for desired entry
		for (iii = 0; iii < fs->bytesPerSector; iii += 32) {
			DBG_SPAM_printf("Searching record '%8.8s.%3.3s'.", buffer + iii, buffer + iii + 8);

			if (buffer[iii] == 0x00 || buffer[iii] == 0xe5) {	// Available entry
				DBG_printf("Available entry found.");

				FATCreateDirectoryTableEntry(buffer+iii, name, ext);

				strncpy((char *) file->name, (char*)buffer+iii, 8);
				strncpy((char *) file->ext, (char*)buffer+iii+8, 3);

				file->directoryTableBlock = currentLBA;
				file->directoryTableOffset = iii / 32;
				file->startClusterNumber = 0;
				file->size = 0;

				file->currentClusterNumber = 0;
				file->currentPosition = 0;

				SD_SPI_WriteSingleBlock(fs->card, currentLBA, buffer);

				dir->directoryTableAvailableCluster = currentCluster;
				dir->directoryTableAvailableClusterOffset = clusterOffset;
				dir->directoryTableAvailableLBA = currentLBA;

				return 1;
			}
		}

		// Advance to next block
		clusterOffset++;
		if (clusterOffset >= fs->sectorsPerCluster) {	// End of cluster
			currentCluster = getNextCluster(fs, currentCluster);
			DBG_DATA_printf("Next cluster = 0x%08lx", currentCluster);
			// Sanity check: ensure Directory Table cluster is valid
			if (currentCluster >= 0xF0000000) {
				DBG_printf("Error creating file (searched past end of Directory Table Cluster).");
				return -1;
			}
			currentLBA = GetClusterLBA(fs, currentCluster);
			clusterOffset = 0;
		} else {	// Advance to next block within cluster
			currentLBA++;
		}
	}
}

/**
 * "Opens" the file - searches the file table for the entry containing the file,
 * and seeks to the beginning of the file.
 * After this function returns successfully, it should be possible to read the file
 * from the beginning or overwrite the file at the beginning.
 * If there is any conflict in filenames, this returns the first file in the directory
 * table with a matching name.
 * Note that this does not actually perform any file reads, but only initialize pointers.
 *
 * @param[in] fs Filesystem structure.
 * @param[in] dir Directory structure.
 * @param[out] file Output file structure.
 * @param[in] name File name, up to 8 characters.
 * @param[in] ext File extension, up to 3 characters, leave NULL for wildcard.
 * @retval 1 Success
 * @retval -1 File not found
 * @retval -2 SD Card Error
 */
int8_t FAT32_OpenFile(FAT32FS *fs, FAT32Directory *dir, FAT32File *file, char *name, char *ext) {
	uint32_t currentCluster = dir->directoryTableBeginCluster;
	fs_addr_t currentLBA = GetClusterLBA(fs, currentCluster);
	uint8_t clusterOffset = 0;		// block number within the cluster

	uint8_t buffer[BLOCK_SIZE];
	fs_length_t iii = 0;

	DBG_DATA_printf("Starting cluster = 0x%08lx", currentCluster);

	while (1) {
		if (BLOCK_SIZE != SD_SPI_ReadSingleBlock(fs->card, currentLBA, buffer)) {
			DBG_printf("File not found (SD Read error on LBA = 0x%08lx).", currentLBA);
			return -2;			// Sanity check: Not reading the correct number of bytes
		}
		DBG_DATA_printf("Read Directory Table LBA = 0x%08lx", currentLBA)

		// Search Directory Table for desired entry
		for (iii = 0; iii < fs->bytesPerSector; iii += 32) {
			if ((buffer[iii]) == 0x00) {	// Entry available and no subsequent entry in use (end of directory table)
				DBG_printf("File not found (searched past end of Directory Table).");
				return -1;
			}

			DBG_SPAM_printf("Directory Table entry '%8.8s.%3.3s'", buffer + iii, buffer + iii + 8);
			if (strncmp(name, (char*)buffer + iii, 8) != 0) {
				continue;
			}
			if ((ext != NULL) && (strncmp(ext, (char*)buffer + iii + 8, 3) != 0)) {
				continue;
			}
			DBG_DATA_printf("File found.");

			strncpy((char *) file->name, (char*)buffer+iii, 8);
			strncpy((char *) file->ext, (char*)buffer+iii+8, 3);

			file->directoryTableBlock = currentLBA;
			file->directoryTableOffset = iii / 32;

			file->startClusterNumber = FATSplitDataToInt32(buffer+iii+0x14, buffer+iii+0x1a);
			file->size = FATDataToInt32(buffer+0x1c);

			file->currentClusterNumber = file->startClusterNumber;
			file->currentPosition = 0;

			DBG_DATA_printf("Directory Table Block = 0x%08lx", file->directoryTableBlock);
			DBG_DATA_printf("File Start Cluster = 0x%08lx", file->startClusterNumber)
			DBG_DATA_printf("File Size = 0x%08lx", file->size)

			return 1;
		}

		// Advance to next block
		clusterOffset++;
		if (clusterOffset >= fs->sectorsPerCluster) {	// End of cluster
			currentCluster = getNextCluster(fs, currentCluster);
			DBG_DATA_printf("Next cluster = 0x%08lx", currentCluster);
			// Sanity check: ensure Directory Table cluster is valid
			if (currentCluster >= 0xF0000000) {
				DBG_printf("File not found (searched past end of Directory Table Cluster).");
				return -1;
			}
			currentLBA = GetClusterLBA(fs, currentCluster);
			clusterOffset = 0;
		} else {	// Advance to next block within cluster
			currentLBA++;
		}
	}
}

/**
 * "Closes" the file.
 * For a file that was only read, nothing happens.
 * For a file that was written, size must be updated and buffers must be flushed.
 *
 * @param[in] file File to "close".
 * @retval 1 Success
 * @retval -1 Nothing to close
 */
int8_t FAT32_CloseFile(FAT32File *file) {
	//TODO Add Flushing Support for Buffered Files
	return 1;
}
