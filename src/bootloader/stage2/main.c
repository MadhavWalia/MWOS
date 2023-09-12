#include "stdint.h"
#include "stdio.h"

void _cdecl cstart_(uint16_t boot_drive) {
    puts("Hello, World!");
    printf("Boot drive: %d\n", boot_drive);
    printf("0x%x\n", 0xdead);
    for(;;);
}
