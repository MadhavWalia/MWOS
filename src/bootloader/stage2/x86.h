#pragma once
#include "stdint.h"

void _cdecl x86_div64_32(uint64_t dividend, uint32_t divisor, uint64_t* quotient, uint32_t* remainder);

void _cdecl x86_video_writeChar(char c, uint8_t page);

bool _cdecl x86_Disk_Reset(uint8_t drive);

bool _cdecl x86_Disk_Read(
  uint8_t drive, 
  uint16_t cylinder, 
  uint16_t head, 
  uint16_t sector, 
  uint8_t count, 
  uint8_t far* dataOut,
);

bool _cdecl x86_Disk_GetDriveParameters(
  uint8_t drive, 
  uint8_t* driveTypeOut, 
  uint16_t* cylindersOut, 
  uint16_t* sectorsOut, 
  uint16_t* headsOut,
);
