/*
 * File:   fat32-file-opt.c
 * Author: Ducky
 *
 * Created on April 25, 2011, 1:10 AM
 */

/**
 * IMPORTANT! For the current optimized write code to work, the following
 *	conditions must be met:
 * - Only one file is written at a time
 * - The FAT32 additional information (containing most recently allocated cluster)
 *	is accurate.
 */

#include "sd-spi.h"
#include "sd-spi-dma.h"
#include <string.h>

#include "fat32-debug.h"
#include "fat32.h"
#include "fat32-file.h"
#include "fat32-file-opt.h"

/**
 * Initializes FAT data for a new file.
 * This fills in the first FAT block and updates the directory table entry.
 * No data is committed not is data moved to the FS buffer - that must be done separately.
 *
 * @pre The file is new (just created).
 *
 * @param file File to initialize.
 * @return Status.
 * @retval 0 Success.
 * @retval -1 Failure.
 */
int8_t FAT32_InitializeFileFAT(FAT32FileOpt *file) {
	// Fill the first FAT block
	FAT32_AllocateFATBlock(file);

	// Use the newly allocated FAT block
	FAT32_SwitchNextBlock(file);

	// Fill out file parameters using allocated data
	file->startCluster = file->currentCluster;
	Int32ToFATSplitData(file->directoryTableBlockData + file->directoryTableBlockOffset + 0x14,
			file->directoryTableBlockData + file->directoryTableBlockOffset + 0x1a,
			file->startCluster);
	FAT32_UpdateDirectoryTableEntry(file);

	DBG_DATA_printf("File initialized (cluster=0x%08lx, block=0x%08lx, size=%lu)", file->currentCluster, file->currentLBA, file->size);
}

/**
 * This is called at the end of a block to switch to the next allocated block
 * @pre The next block has already been allocated and committed to disk
 * @pre No outstanding operations are left on the previous block -
 * dirty FAT data block, FS information sector, and directory table entry
 * have all been committed to disk.
 * @param file File
 */
void FAT32_SwitchNextBlock(FAT32FileOpt *file) {
	// Move the current FAT data to the previous one, and mark the current one as empty
	file->previousFATBlockData = file->currentFATBlockData;
	file->previousFATLBA = file->currentFATLBA;
	file->previousFATBlockOffset = file->currentFATBlockOffset;
	file->previousFATDirty = 0;
	file->currentFATAllocated = 0;

	// Update current cluster pointers
	file->currentCluster = file->nextClusterBegin;
	file->currentClusterEnd = file->nextClusterEnd;
	file->position = file->previousFileSize;
	file->previousFileSize = file->size;
	file->currentClusterLBAOffset = 0;
	file->currentLBA = GetClusterLBA(file->fs, file->currentCluster);
}

/**
 * This fills the file's currentFATData buffer with the next block of FAT data to write.
 * If the next block is not the previously predicted block, then the previousFATData
 * cache is modified to account for this, and the previousFATDirty byte is set to 1.
 * If the cluster pointer to the beginning of the next block does not reside at
 * the beginning block boundary, the entire block is read in and the relevant portions
 * are updated.
 *
 * @param file File to fill for.
 * @return Number of clusters allocated
 */
uint16_t FAT32_AllocateFATBlock(FAT32FileOpt *file) {
	uint16_t clusterPointer;
	uint32_t nextCluster = file->fs->mostRecentCluster + 1;
	uint16_t numAllocatedClusters = 0;

	// Check next cluster allocated against the last cluster link
	if (FATDataToInt32(file->previousFATBlockData + file->previousFATBlockOffset) != nextCluster) {
		Int32ToFATData(file->previousFATBlockData + file->previousFATBlockOffset, nextCluster);
		file->previousFATDirty = 1;
	}

	clusterPointer = GetClusterFATOffset(file->fs, nextCluster);
	file->currentFATLBA = GetClusterFATLBA(file->fs, nextCluster);
	// If the next cluster pointer isn't on a block boundary, read in the current entries in the block
	if (clusterPointer != 0) {
		DBG_DATA_printf("Reading in FAT data at LBA=0x%08lx (cluster=0x%08lx, offset=0x%04x)",
				file->currentFATLBA, nextCluster, clusterPointer);
		// TODO Make this DMA Friendly
		if (BLOCK_SIZE != SD_SPI_ReadSingleBlock(file->fs->card, file->currentFATLBA, file->currentFATBlockData)) {
			DBG_ERR_printf("Error creating file (SD Read error on LBA = 0x%08lx).", file->currentFATLBA);
			return -1;			// Sanity check: Not reading the correct number of bytes
		}
	}

	// Fill in file table data
	file->nextClusterBegin = file->fs->mostRecentCluster + 1;
	for (;clusterPointer<BLOCK_SIZE;clusterPointer+=file->fs->clusterPointerSize) {
		nextCluster++;
		Int32ToFATData(file->currentFATBlockData+clusterPointer, nextCluster);
	}
	file->currentFATBlockOffset = clusterPointer - file->fs->clusterPointerSize;
	file->nextClusterEnd = nextCluster - 1;

	// Mark as allocated
	file->currentFATAllocated = 1;
	file->currentFATDirty = 1;

	// Compute new file size
	numAllocatedClusters = (file->nextClusterEnd - file->nextClusterBegin) + 1;
	file->size += (uint32_t)numAllocatedClusters * file->fs->bytesPerSector * file->fs->sectorsPerCluster;
	FAT32_UpdateDirectoryTableEntry(file);

	// Update FS Information sector
	file->fs->mostRecentCluster = file->nextClusterEnd;
	file->fs->numFreeClusters -= numAllocatedClusters;
	file->fs->fsInfoDirty = 1;

	DBG_DATA_printf("Allocated clusters 0x%08lx to 0x%08lx (FAT LBA=0x%08lx), file size=%lu)",
			file->nextClusterBegin, file->nextClusterEnd, file->currentFATLBA, file->size);
	DBG_DATA_printf("Most recent cluster=0x%08lx, num free clusters=%lu", file->fs->mostRecentCluster, file->fs->numFreeClusters);

	return numAllocatedClusters;
}

/**
 * Fills the FS buffer with the file's currentFATData.
 * @param file File.
 */
void FAT32_FillCurrentFATBlock(FAT32FileOpt *file) {
	memcpy(file->fsBuffer, file->currentFATBlockData, BLOCK_SIZE);
}

/**
 * Fills the FS buffer with the file's previousFATData.
 * @param file File.
 */
void FAT32_FillPreviousFATBlock(FAT32FileOpt *file) {
	memcpy(file->fsBuffer, file->previousFATBlockData, BLOCK_SIZE);
}

/**
 * Updates the file's directory table entry with current paramters like size.
 * @param file File for which the directory table entry is updated.
 */
void FAT32_UpdateDirectoryTableEntry(FAT32FileOpt *file) {
	Int32ToFATData(file->directoryTableBlockData + file->directoryTableBlockOffset + 0x1c, file->size);
	file->directoryTableDirty = 1;
}

/**
 * Fills the FS buffer with the file's directory table block.
 * @param file File.
 */
void FAT32_FillDirectoryTableBlock(FAT32FileOpt *file) {
	memcpy(file->fsBuffer, file->directoryTableBlockData, BLOCK_SIZE);
}

/**
 * Fills the FS buffer with the updated FS Information Sector for FAT32.
 * @param file File.
 */
void FAT32_FillFSInformationSector(FAT32FileOpt *file) {
	uint16_t i = 0;
	file->fsBuffer[0x00] = 0x52;
	file->fsBuffer[0x01] = 0x52;
	file->fsBuffer[0x02] = 0x61;
	file->fsBuffer[0x03] = 0x41;
	for (i=0x04;i<0x1e4;i++) {
		file->fsBuffer[i] = 0x00;
	}
	file->fsBuffer[0x1e4] = 0x72;
	file->fsBuffer[0x1e5] = 0x72;
	file->fsBuffer[0x1e6] = 0x61;
	file->fsBuffer[0x1e7] = 0x41;
	Int32ToFATData(file->fsBuffer + 0x1e8, file->fs->numFreeClusters);
	Int32ToFATData(file->fsBuffer + 0x1ec, file->fs->mostRecentCluster);
	for (i=0x1f0;i<0x1fe;i++) {
		file->fsBuffer[i] = 0x00;
	}
	file->fsBuffer[0x1fe] = 0x55;
	file->fsBuffer[0x1ff] = 0xaa;
}

/**
 * Write /a data of length /a length into the file's overflow buffer and updates
 * variables accordingly.
 * @pre /a length is not larger than the remaining space available.
 *
 * @param file File.
 * @param data Pointer to the beginning of the data to write.
 * @param length Length, in bytes, of the data to write.
 */
void FAT32_WriteOverflowBuffer(FAT32FileOpt *file, uint8_t *data, fs_length_t length) {
	fs_length_t copyLength = FAT32_OVERFLOW_BUFFER_SIZE - file->overflowBufferEnd;
	if (length <= copyLength) {
		// Writing data won't wrap around to beginning of circular buffer
		memcpy(file->overflowBuffer + file->overflowBufferEnd, data, length);
		file->overflowBufferEnd += length;
	} else {
		// Writing data will wrap around to beginning of circular buffer
		memcpy(file->overflowBuffer + file->overflowBufferEnd, data, copyLength);
		memcpy(file->overflowBuffer, data, length - copyLength);
		file->overflowBufferEnd = length - copyLength;
	}

	file->overflowBufferSize += length;

	if (file->overflowBufferEnd >= FAT32_OVERFLOW_BUFFER_SIZE) {
		file->overflowBufferEnd = 0;
	}
}

/**
 * Moves data from the overflow buffer to the main data buffer.
 * @param file
 */
void FAT32_MoveOverflowToData(FAT32FileOpt *file) {
	while (file->overflowBufferSize > 0) {
		if (file->dataBufferNumFilled < FAT32_NUM_DATA_BUFFERS) {
			// if data buffers are available
			fs_length_t writeLength = file->overflowBufferSize;
			if (writeLength > FAT32_OVERFLOW_BUFFER_SIZE - file->overflowBufferBegin) {
				writeLength = FAT32_OVERFLOW_BUFFER_SIZE - file->overflowBufferBegin;
			}
			if (writeLength > BLOCK_SIZE - file->dataBufferPos) {
				writeLength = BLOCK_SIZE - file->dataBufferPos;
			}
			memcpy(file->dataBuffer[file->dataBufferFill] + file->dataBufferPos,
					file->overflowBuffer + file->overflowBufferBegin, writeLength);

			file->overflowBufferSize -= writeLength;
			file->overflowBufferBegin += writeLength;
			if (file->overflowBufferBegin >= FAT32_OVERFLOW_BUFFER_SIZE) {
				file->overflowBufferBegin = 0;
			}

			file->dataBufferPos += writeLength;

			DBG_DATA_printf("Copied %u bytes from overflow into DMA buffer %u, DMA size=%u, overflow size = %u",
					writeLength, file->dataBufferFill, file->dataBufferPos, file->overflowBufferSize);

			if (file->dataBufferPos >= BLOCK_SIZE) {
				file->dataBufferPos = 0;
				file->dataBufferNumFilled++;
				file->dataBufferFill++;
				if (file->dataBufferFill >= FAT32_NUM_DATA_BUFFERS) {
					file->dataBufferFill = 0;
				}
				DBG_DATA_printf("Advanced to DMA buffer %u, numDataBuffers=%u", file->dataBufferFill, file->dataBufferNumFilled);
			}
		} else {
			return;
		}
	}
}

/**
 * Writes /a data into the file buffers.
 * @param file File.
 * @param data Pointer to the beginning of the data to write.
 * @param length Length, in bytes, of the data to write.
 * @return Number of bytes written to the buffer. Usually the length of the input data,
 * unless the buffers are full.
 */
fs_length_t FAT32_WriteBuffer(FAT32FileOpt *file, uint8_t *data, fs_length_t length) {
	fs_length_t remaining = length;

	if (file->overflowBufferSize > 0 && file->dataBufferNumFilled < FAT32_NUM_DATA_BUFFERS) {
		FAT32_MoveOverflowToData(file);
	}

	while (remaining > 0) {
		if (file->dataBufferNumFilled >= FAT32_NUM_DATA_BUFFERS) {
			// All DMA buffers full, go to overflow buffer
			if (file->overflowBufferSize >= FAT32_OVERFLOW_BUFFER_SIZE) {
				// Overflow buffer is full - operation fails to write all data
				return length - remaining;
			} else {
				// Overflow buffer has positions available
				fs_length_t writeLength = remaining;
				if (remaining > FAT32_OVERFLOW_BUFFER_SIZE - file->overflowBufferSize) {
					writeLength = FAT32_OVERFLOW_BUFFER_SIZE - file->overflowBufferSize;
				}
				FAT32_WriteOverflowBuffer(file, data, writeLength);
				remaining -= writeLength;
				data += writeLength;
			}
		} else {
			// Empty positions available in DMA buffers, fill those
			fs_length_t writeLength = remaining;
			if (remaining > BLOCK_SIZE - file->dataBufferPos) {
				writeLength = BLOCK_SIZE - file->dataBufferPos;
			}
			memcpy(file->dataBuffer[file->dataBufferFill] + file->dataBufferPos, data, writeLength);
			file->dataBufferPos += writeLength;
			if (file->dataBufferPos >= BLOCK_SIZE) {
				file->dataBufferPos = 0;
				file->dataBufferNumFilled++;
				file->dataBufferFill++;
				if (file->dataBufferFill >= FAT32_NUM_DATA_BUFFERS) {
					file->dataBufferFill = 0;
				}
				DBG_DATA_printf("Advanced to DMA buffer %u, numDataBuffers=%u", file->dataBufferFill, file->dataBufferNumFilled);
			}

			remaining -= writeLength;
			data += writeLength;
		}
	}

	return length;
}

/**
 * Creates a file (creates the directory entry for a file) for optimized write.
 * After this function returns successfully, it should be possible to do optimized
 * writes on the file starting at the beginning.
 * No checks are done against duplicate file name, and no clusters are allocated.
 * File space is allocated during write operations.
 *
 * @param[in] fs Filesystem structure.
 * @param[in] dir Directory structure.
 * @param[out] fileOpt Output optimized file structure.
 * @param[in] name File name, up to 8 characters.
 * @param[in] ext File extension, up to 3 characters.
 * @retval 1 Success
 * @retval -1 Error creating file
 * @retval -2 SD Card Error
 * @retval -128 General error
 */
int8_t FAT32_CreateFileOpt(FAT32FS *fs, FAT32Directory *dir, FAT32FileOpt *file, char *name, char *ext) {
	uint32_t currentCluster = dir->directoryTableAvailableCluster;
	fs_addr_t currentLBA = dir->directoryTableAvailableLBA;
	uint8_t clusterOffset = dir->directoryTableAvailableClusterOffset;	// block number within the cluster

	fs_length_t iii = 0;

	DBG_DATA_printf("Starting cluster = 0x%08lx", currentCluster);

	// Search for an empty file
	while (1) {
		if (BLOCK_SIZE != SD_SPI_ReadSingleBlock(fs->card, currentLBA, file->directoryTableBlockData)) {
			DBG_printf("Error creating file (SD Read error on LBA = 0x%08lx).", currentLBA);
			return -2;			// Sanity check: Not reading the correct number of bytes
		}
		DBG_DATA_printf("Read Directory Table LBA = 0x%08lx", currentLBA)

		// Search Directory Table for desired entry
		for (iii = 0; iii < fs->bytesPerSector; iii += 32) {
			DBG_SPAM_printf("Searching record '%8.8s.%3.3s'.", file->directoryTableBlockData + iii, file->directoryTableBlockData + iii + 8);

			if (file->directoryTableBlockData[iii] == 0x00 || file->directoryTableBlockData[iii] == 0xe5) {	// Available entry
				DBG_printf("Available entry found.");

				// Update directory structure with new end
				dir->directoryTableAvailableCluster = currentCluster;
				dir->directoryTableAvailableClusterOffset = clusterOffset;
				dir->directoryTableAvailableLBA = currentLBA;

				FATCreateDirectoryTableEntry(file->directoryTableBlockData+iii, name, ext);

				// Fill out file structure

				strncpy((char *) file->name, (char*)file->directoryTableBlockData+iii, 8);
				strncpy((char *) file->ext, (char*)file->directoryTableBlockData+iii+8, 3);

				file->fs = fs;

				file->directoryTableLBA = currentLBA;
				file->directoryTableBlockOffset = iii;
				file->directoryTableDirty = 0;

				file->startCluster = 0;
				file->size = 0;

				file->previousFATBlockData = file->previousFATData;
				file->currentFATBlockData = file->currentFATData;

				file->previousFATBlockOffset = 0;
				file->previousFATDirty = 0;
				file->previousFileSize = 0;

				file->currentCluster = 0;
				file->currentLBA = 0;
				file->position = 0;

				file->currentOperation = FILE_OP_None;
				file->nextOperation = FILE_OP_WritingDataIdle;

				file->dataBuffer[0] = SD_DMA_GetBuffer(0);
				if (file->dataBuffer[0] == NULL) {
					DBG_ERR_printf("Error allocating DMA buffer 0");
					return -128;
				}
				file->dataBuffer[1] = SD_DMA_GetBuffer(1);
				if (file->dataBuffer[1] == NULL) {
					DBG_ERR_printf("Error allocating DMA buffer 1");
					return -128;
				}
				file->fsBuffer = SD_DMA_GetBuffer(2);
				if (file->fs == NULL) {
					DBG_ERR_printf("Error allocating DMA FS buffer");
					return -128;
				}
				file->dataBufferWrite = 0;
				file->dataBufferFill = 0;
				file->dataBufferNumFilled = 0;
				file->dataBufferPos = 0;

				file->overflowBufferBegin = 0;
				file->overflowBufferEnd = 0;
				file->overflowBufferSize = 0;

				FAT32_InitializeFileFAT(file);

				SD_SPI_WriteSingleBlock(fs->card, file->directoryTableLBA, file->directoryTableBlockData);
				file->directoryTableDirty = 0;

				SD_SPI_WriteSingleBlock(fs->card, file->currentFATLBA, file->currentFATBlockData);
				file->currentFATAllocated = 0;

				FAT32_FillFSInformationSector(file);
				SD_SPI_WriteSingleBlock(fs->card, fs->FS_info_LBA, file->fsBuffer);
				file->fs->fsInfoDirty = 0;


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

void FAT32_Tasks(FAT32FileOpt *file) {
	if (file->currentOperation == FILE_OP_None) {
		// Check if there is a queued command - and if so, start it
		if (file->nextOperation == FILE_OP_WritingDataIdle) {
			SD_DMA_MBW_Start(file->fs->card, file->currentLBA);
			file->currentOperation = FILE_OP_WritingDataIdle;
			DBG_SPAM_printf("file->currentOperation going to FILE_OP_WritingDataIdle (queued)");
		} else if (file->nextOperation == FILE_OP_WritingDirectoryTable) {
			SD_DMA_MBW_Start(file->fs->card, file->directoryTableLBA);
			SD_DMA_MBW_SendBlock(2);
			file->currentOperation = FILE_OP_WritingDirectoryTable;
			DBG_SPAM_printf("file->currentOperation going to FILE_OP_WritingDirectoryTable (queued)");
		} else if (file->nextOperation == FILE_OP_WritingFAT) {
			SD_DMA_MBW_Start(file->fs->card, file->currentFATLBA);
			SD_DMA_MBW_SendBlock(2);
			file->currentOperation = FILE_OP_WritingFAT;
			DBG_SPAM_printf("file->currentOperation going to FILE_OP_WritingFAT (queued)");
		} else if (file->nextOperation == FILE_OP_WritingFSInformation) {
			SD_DMA_MBW_Start(file->fs->card, file->fs->FS_info_LBA);
			SD_DMA_MBW_SendBlock(2);
			file->currentOperation = FILE_OP_WritingFSInformation;
			DBG_SPAM_printf("file->currentOperation going to FILE_OP_WritingFSInformation (queued)");
		}
		// Check if we passed the allocation boundaries
		if (file->currentCluster > file->currentClusterEnd) {
			// Check if more bookkeeping needs to be done
			if (!file->currentFATAllocated) {
				FAT32_AllocateFATBlock(file);
				FAT32_FillCurrentFATBlock(file);
				SD_DMA_MBW_Start(file->fs->card, file->currentFATLBA);
				SD_DMA_MBW_SendBlock(2);
				file->currentOperation = FILE_OP_WritingFAT;
				DBG_SPAM_printf("file->currentOperation going to FILE_OP_WritingFAT (end of allocation)");
			} else if (file->currentFATDirty) {
				FAT32_FillCurrentFATBlock(file);
				SD_DMA_MBW_Start(file->fs->card, file->currentFATLBA);
				SD_DMA_MBW_SendBlock(2);
				file->currentOperation = FILE_OP_WritingFAT;
				DBG_SPAM_printf("file->currentOperation going to FILE_OP_WritingFAT (end of allocation)");
			} else if (file->directoryTableDirty) {
				FAT32_FillDirectoryTableBlock(file);
				SD_DMA_MBW_Start(file->fs->card, file->directoryTableLBA);
				SD_DMA_MBW_SendBlock(2);
				file->currentOperation = FILE_OP_WritingDirectoryTable;
				DBG_SPAM_printf("file->currentOperation going to FILE_OP_WritingDirectoryTable (end of allocation)");
			} else if (file->fs->fsInfoDirty) {
				FAT32_FillFSInformationSector(file);
				SD_DMA_MBW_Start(file->fs->card, file->fs->FS_info_LBA);
				SD_DMA_MBW_SendBlock(2);
				file->currentOperation = FILE_OP_WritingFSInformation;
				DBG_SPAM_printf("file->currentOperation going to FILE_OP_WritingFSInformation (end of allocation)");
			} else {
				FAT32_SwitchNextBlock(file);
				DBG_DATA_printf("Switching to next block");
			}
		} else {
			SD_DMA_MBW_Start(file->fs->card, file->currentLBA);
			file->currentOperation = FILE_OP_WritingDataIdle;
		}
	} else if (file->currentOperation == FILE_OP_WritingDataIdle) {
		// Check the current SD DMA state
		if (SD_DMA_MBW_GetIdle()) {
			// Check is we have passed the allocation boundaries
			if (file->currentCluster > file->currentClusterEnd) {
				SD_DMA_MBW_End();
				file->currentOperation = FILE_OP_MultipleBlockWriteTerminate;
				file->nextOperation = FILE_OP_None;
				DBG_SPAM_printf("file->currentOperation going to FILE_OP_MultipleBlockWriteTerminate (allocation exceeded)");
			} else {
				// Check is there is a new block ready to send
				if (file->dataBufferNumFilled > 0) {
					DBG_SPAM_printf("Writing data block at LBA=0x%08lx, cluster=0x%08lx, allocated end=0x%08lx, buffer=%u",
							file->currentLBA, file->currentCluster, file->currentClusterEnd, file->dataBufferWrite);
					// Send the new block
					SD_DMA_MBW_SendBlock(file->dataBufferWrite);
					file->currentOperation = FILE_OP_WritingData;
				} else {
					// No data available, check if we have bookkeeping to do
					// TODO Terminate block write mid-write and do bookkeeping
				}
			}
		}

	} else if (file->currentOperation == FILE_OP_WritingData) {
		uint8_t status = SD_DMA_MBW_GetBlockStatus();
		if (status != 0x00) {
			// Current block is done, advance the data buffers
			DBG_SPAM_printf("SD_DMA_MBW_GetBlockStatus returned 0x%02x", status);
			file->dataBufferWrite++;
			if (file->dataBufferWrite >= FAT32_NUM_DATA_BUFFERS) {
				file->dataBufferWrite = 0;
			}
			file->dataBufferNumFilled--;
			file->currentLBA++;
			file->currentClusterLBAOffset++;
			if (file->currentClusterLBAOffset >= file->fs->sectorsPerCluster) {
				file->currentCluster++;
				file->currentClusterLBAOffset = 0;
			}
			file->position += file->fs->bytesPerSector;
			file->currentOperation = FILE_OP_WritingDataIdle;
		}
	} else if (file->currentOperation == FILE_OP_WritingDirectoryTable
			|| file->currentOperation == FILE_OP_WritingFAT
			|| file->currentOperation == FILE_OP_WritingFSInformation) {
		uint8_t status = SD_DMA_MBW_GetBlockStatus();
		if (status != 0x00) {
			// Block complete, terminate command
			SD_DMA_MBW_End();
			if (file->currentOperation == FILE_OP_WritingDirectoryTable) {
				file->directoryTableDirty = 0;
			} else if (file->currentOperation == FILE_OP_WritingFAT) {
				file->currentFATDirty = 0;
			} else if (file->currentOperation == FILE_OP_WritingFSInformation) {
				file->fs->fsInfoDirty = 0;
			}
			file->currentOperation = FILE_OP_MultipleBlockWriteTerminate;
			file->nextOperation = FILE_OP_None;
			DBG_SPAM_printf("file->currentOperation going to FILE_OP_MultipleBlockWriteTerminate (operation complete)");
		} else {
			DBG_SPAM_printf("SD_DMA_MBW_GetBlockStatus returned 0x%02x", status);
		}
	} else if (file->currentOperation == FILE_OP_MultipleBlockWriteTerminate) {
		uint8_t status = SD_DMA_MBW_GetBlockStatus();
		if (status != 0x00) {
			file->currentOperation = FILE_OP_None;
			DBG_SPAM_printf("file->currentOperation going to FILE_OP_None");
		} else {
			DBG_SPAM_printf("SD_DMA_MBW_GetBlockStatus returned 0x%02x", status);
		}
	}
}

/**
 * Writes data to a file using the optimized write procedure.
 * @param file File to write data to.
 * @param data Pointer to the beginning of the data.
 * @param dataLen Length, in bytes, of the data to write.
 * @return Number of bytes written.
 */
fs_length_t FAT32_WriteFileOpt(FAT32FileOpt *file, uint8_t *data, fs_length_t dataLen) {
	fs_length_t bytesWritten;

	FAT32_Tasks(file);

	if (dataLen > 0) {
		bytesWritten = FAT32_WriteBuffer(file, data, dataLen);
		FAT32_Tasks(file);
	} else {
		bytesWritten = 0;
	}

	return bytesWritten;
}

void FAT32_Terminate(FAT32FileOpt *file) {
	DBG_DATA_printf("Terminate: data buffers remaining=%u", file->dataBufferNumFilled);

	// Wait for all outstanding buffers to be committed to disk.
	while (file->dataBufferNumFilled > 0 || file->overflowBufferSize > 0) {
		FAT32_MoveOverflowToData(file);
		FAT32_Tasks(file);
	}
	
	// If last buffer is partially full, zero the rest of the data and commit it.
	if (file->dataBufferPos > 0) {
		uint16_t pos = file->dataBufferPos;
		uint16_t zeroFill = file->fs->bytesPerSector - file->dataBufferPos;
		DBG_DATA_printf("Terminate: partial data buffer, position=%u", file->dataBufferPos);

		for (pos = file->dataBufferPos; pos<file->fs->bytesPerSector; pos++) {
			file->dataBuffer[file->dataBufferFill][pos] = 0;
		}
		file->dataBufferNumFilled++;
		file->dataBufferFill++;
		if (file->dataBufferFill >= FAT32_NUM_DATA_BUFFERS) {
			file->dataBufferFill = 0;
		}
		while (file->dataBufferNumFilled > 0) {
			FAT32_Tasks(file);
		}
		file->position -= zeroFill;
	}

	DBG_DATA_printf("Terminate: stopping DMA MBW operations");
	SD_DMA_MBW_End();
	while (SD_DMA_MBW_GetBlockStatus() == 0x00);

	// Update file size
	file->size = file->position;
	FAT32_UpdateDirectoryTableEntry(file);
	DBG_DATA_printf("Terminate: Updating directory table at LBA=0x%08lx, file size=0x%08lx",
			file->directoryTableLBA, file->size);
	SD_SPI_WriteSingleBlock(file->fs->card, file->directoryTableLBA, file->directoryTableBlockData);
	file->directoryTableDirty = 0;

	// Update FAT
	// Deallocate unused clusters
	uint16_t clusterBegin = GetClusterFATOffset(file->fs, file->currentCluster);
	DBG_DATA_printf("Terminate: Deallocating previous FAT block starting cluster=0x%08lx, offset=%u",
			file->currentCluster, clusterBegin);
	Int32ToFATData(file->previousFATBlockData + clusterBegin, 0x0fffffff);
	clusterBegin+= file->fs->clusterPointerSize;
	for (; clusterBegin < file->fs->bytesPerSector; clusterBegin += file->fs->clusterPointerSize) {
		Int32ToFATData(file->previousFATBlockData + clusterBegin, 0x00000000);
	}
	DBG_DATA_printf("Terminate: Updating previous FAT block at LBA=0x%08lx", file->previousFATLBA);
	SD_SPI_WriteSingleBlock(file->fs->card, file->previousFATLBA, file->previousFATBlockData);

	// Deallocate the next block
	if (file->currentFATAllocated && !file->currentFATDirty) {
		DBG_DATA_printf("Terminate: Deallocating current FAT block");
		for (clusterBegin = 0; clusterBegin < file->fs->bytesPerSector; clusterBegin += file->fs->clusterPointerSize) {
			Int32ToFATData(file->currentFATBlockData + clusterBegin, 0x00000000);
		}
		DBG_DATA_printf("Terminate: Updating current FAT block at LBA=0x%08lx", file->currentFATLBA);
		SD_SPI_WriteSingleBlock(file->fs->card, file->currentFATLBA, file->currentFATBlockData);
	}
	
	// Update FS Information Sector
	file->fs->mostRecentCluster = file->currentCluster;
	
}
