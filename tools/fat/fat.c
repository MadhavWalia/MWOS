#include<stdio.h>
#include<stdint.h>
#include<stdlib.h>
#include<string.h>
#include<ctype.h>

// Boolan type for C
typedef uint8_t bool;
#define true 1
#define false 0


// Boot sector structure
typedef struct {
    uint8_t BootJumpInstruction[3];
    uint8_t OemIdentifier[8];
    uint16_t BytesPerSector;
    uint8_t SectorsPerCluster;
    uint16_t ReservedSectors;
    uint8_t FatCount;
    uint16_t DirEntryCount;
    uint16_t TotalSectors;
    uint8_t MediaDescriptorType;
    uint16_t SectorsPerFat;
    uint16_t SectorsPerTrack;
    uint16_t Heads;
    uint32_t HiddenSectors;
    uint32_t LargeSectorCount;

    // Extended Boot Record
    uint8_t DriveNumber;
    uint8_t _Reserved;
    uint8_t Signature;
    uint32_t VolumeId;
    uint8_t VolumeLabel[11];
    uint8_t SystemId[8];

    // The boot code follows here (not required as part of the struct)

} __attribute__((packed)) BootSector;


typedef struct {
    uint8_t Name[11];
    uint8_t Attributes;
    uint8_t _Reserved;
    uint8_t CreationTimeTenths;
    uint16_t CreatedTime;
    uint16_t CreatedDate;
    uint16_t AccessedDate;
    uint16_t FirstClusterHigh;
    uint16_t ModifiedTime;
    uint16_t ModifiedDate;
    uint16_t FirstClusterLow;
    uint32_t FileSize;
} __attribute__((packed)) DirectoryEntry;


BootSector g_BootSector;
uint8_t* g_fat = NULL;
DirectoryEntry* g_RootDirectory = NULL;
uint32_t g_RootDirectoryEnd;


/*
Functions to read the Reserved Sectors, the FAT and the Root Directory from the disk
*/


// Read the boot sector from the disk to the global variable g_bootSector
// Return true if the boot sector was read successfully
bool readBootSector(FILE* disk) {
    return fread(&g_BootSector, sizeof(BootSector), 1, disk) > 0;
}

// Read sectors from the disk 
bool readSectors(FILE* disk, uint32_t lba, uint32_t count, void* bufferOut) {
    bool ok = true;

    ok = ok && (fseek(disk, lba * g_BootSector.BytesPerSector, SEEK_SET) == 0);
    ok = ok && (fread(bufferOut, g_BootSector.BytesPerSector, count, disk) == count);

    return ok;
}

// Reading the FAT from the disk
bool readFAT(FILE* disk) {
    g_fat = (uint8_t*)malloc(g_BootSector.SectorsPerFat * g_BootSector.BytesPerSector);
    return readSectors(disk, g_BootSector.ReservedSectors, g_BootSector.SectorsPerFat, g_fat);
}

// Reading the root directory from the disk
bool readRootDirectory(FILE* disk) {
    uint32_t lba = g_BootSector.ReservedSectors + g_BootSector.SectorsPerFat * g_BootSector.FatCount;
    uint32_t size = g_BootSector.DirEntryCount * sizeof(DirectoryEntry);
    uint32_t sectors = (size) / g_BootSector.BytesPerSector;
    // Round up to the next sector
    if (size % g_BootSector.BytesPerSector > 0) {
        sectors++;
    }

    // Storing the end of the root directory for later use
    g_RootDirectoryEnd = lba + sectors;

    // Using sectors instead of size to avoid integer overflow as the readSectors function only reads full sectors
    g_RootDirectory = (DirectoryEntry*)malloc(sectors * g_BootSector.BytesPerSector);
    return readSectors(disk, lba, sectors, g_RootDirectory);
}


/*
Functions to read the data from the disk
*/


// Find the file in the root directory
DirectoryEntry* findFile(const char* name) {

    // Iterating over the root directory and comparing the filename
    for(uint32_t i=0; i < g_BootSector.DirEntryCount; i++) {
        if (memcmp(name, g_RootDirectory[i].Name, 11) == 0) {
            return &g_RootDirectory[i];
        }
    }

    return NULL;
}


bool readFile(DirectoryEntry* fileEntry, FILE* disk, uint8_t* outputBuffer) {

    bool ok = true;
    uint16_t currentCluster = fileEntry->FirstClusterLow;

    do {
        uint32_t lba = g_RootDirectoryEnd + (currentCluster - 2) * g_BootSector.SectorsPerCluster;
        ok = ok && readSectors(disk, lba, g_BootSector.SectorsPerCluster, outputBuffer);
        outputBuffer += g_BootSector.SectorsPerCluster * g_BootSector.BytesPerSector;

        // Reading the next cluster from the FAT
        uint32_t fatIndex = currentCluster * 3 / 2; // FAT entries are 12 bit, so we need to read 1.5 bytes per entry
        if (currentCluster % 2 == 0) {
            // Even cluster number, read the bottom 12 bits
            currentCluster = (*(uint16_t*)(g_fat + fatIndex)) & 0xFFF; // mask out the top 4 bits
        }
        else {
            // Odd cluster number, read the top 12 bits
            currentCluster = (*(uint16_t*)(g_fat + fatIndex)) >> 4; // shift out the bottom 4 bits
        }

    } while (ok && currentCluster < 0xFF8);

    return ok;
}


/*
The main function
*/


int main(int argc, char** argv) {
    if (argc < 3) {
        printf("Syntax %s <disk image> <file name>\n", argv[0]);
        return -1;
    }

    FILE* disk = fopen(argv[1], "rb");
    if (!disk) {
        fprintf(stderr, "Could not open disk image %s\n", argv[1]);
        return -1;
    }

    if (!readBootSector(disk)) {
        fprintf(stderr, "Could not read boot sector\n");
        return -2;
    }

    if (!readFAT(disk)) {
        fprintf(stderr, "Could not read FAT\n");
        free(g_fat);
        return -3;
    }

    if(!readRootDirectory(disk)) {
        fprintf(stderr, "Could not read root directory\n");
        free(g_fat);
        free(g_RootDirectory);
        return -4;
    }

    DirectoryEntry* fileEntry = findFile(argv[2]);
    if (!fileEntry) {
        fprintf(stderr, "Could not find file %s!\n", argv[2]);
        free(g_fat);
        free(g_RootDirectory);
        return -5;
    }

    // Allocating extra space to prevent buffer overflow
    uint8_t* buffer = (uint8_t*)malloc(fileEntry->FileSize + g_BootSector.BytesPerSector);
    if (!readFile(fileEntry, disk, buffer)) {
        fprintf(stderr, "Could not read file %s!\n", argv[2]);
        free(g_fat);
        free(g_RootDirectory);
        free(buffer);
        return -6;
    }

    // Writing the file to stdout
    for (size_t i=0; i < fileEntry->FileSize; i++) {
        if (isprint(buffer[i])) fputc(buffer[i], stdout);
        else printf("<%02x>", buffer[i]);
    }
    printf("\n");

    free(buffer);
    free(g_fat);
    free(g_RootDirectory);
    return 0;
}