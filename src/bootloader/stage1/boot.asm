org 0x7C00   ;  Start the offset from the given address
bits 16      ;  Emit 16-bit code (done for backward compatibilty)


%define ENDL 0x0D, 0x0A    ; Macro for \n (hex for the line feed(\) and carrige return (n))


;
; FAT12 Header
;
jmp short start
nop


OEMLabel: 							db "MSWIN4.1"   				; OEM Label
BytesPerSector: 				dw 512    							; Bytes per sector
SectorsPerCluster: 			db 1   									; Sectors per cluster
ReservedSectors: 				dw 1      							; Reserved sectors
NumberOfFATs: 					db 2        	 					; Number of FATs
RootEntries: 						dw 0E0h      	  				; Number of root entries
TotalSectors: 					dw 2880      						; Total sectors
Media: 									db 0F0h         				; Media descriptor
SectorsPerFAT: 					dw 9          					; Sectors per FAT
SectorsPerTrack: 				dw 18         					; Sectors per track
HeadsPerCylinder: 			dw 2           					; Number of heads
HiddenSectors: 					dd 0           					; Number of hidden sectors
TotalSectorsBig: 				dd 0           					; Number of sectors if over 32 MB


; Extended boot record
DriveNumber: 						db 0           					; Drive number
Reserved: 							db 0           					; Reserved
ExtBootSignature: 			db 29h         					; Extended boot signature
VolumeID: 							db 22h, 42h, 69h, 22h   ; Volume ID
VolumeLabel: 						db "NO NAME    " 				; Volume label
FileSystem: 						db "FAT12   "    				; File system type


;
; Code
;


start:
	; setup the data segments
	mov ax, 0           ;  Can't write to the ds/es segments directly
	mov ds, ax
	mov es, ax

	; setup the stack
	mov ss, ax
	mov sp, 0x7C00      ;  Stack grows downwards from where we are loaded in memory

	; some BIOSes start at 07C0:0000, instead of 0000:7C00
	; so we make sure that we are really at 0000:7C00
	push es 					 ;  Save the current es
	push word .after 	 ;  Push the address of the label .after to jump to it later
	retf 						 	 ;  Pop the address into cs and jump to the address in cs:ip

.after:

	; perform a read operation from the disk
	; The BIOS sets the dl register to the boot drive number
	mov [DriveNumber], dl

	; print loading message
	mov si, msg_loading
	call puts

	; reading the drive parameters (sectors per track and head count) using the BIOS
	; this helps if the formatted disk is not standard or corrupted
	push es
	mov ah, 08h
	int 13h
	jc floppy_error
	pop es

	and cl, 0x3F 								; clear the upper 2 bits of cl for sectors per track
	xor ch, ch 									; clear ch
	mov [SectorsPerTrack], cx 	; store the sectors per track

	inc dh 											; increment dh to get the head count
	mov [HeadsPerCylinder], dx 	; store the head count


	; reading the FAT file system

	; calculate the LBA address of the first sector of the root directory = (reserved sectors + (number of FATs * sectors per FAT))
	mov ax, [SectorsPerFAT]
	mov bl, [NumberOfFATs]

	xor bh, bh 									; clear bh
	mul bl 											; ax = ax * bl ; ax = (number of FATs * sectors per FAT)
	add ax, [ReservedSectors] 	; ax = (reserved sectors + (number of FATs * sectors per FAT))
	push ax
	
	; calculate the size of the root directory in sectors = (root entries * 32) / bytes per sector
	mov ax, [SectorsPerFAT]
	shl ax, 5 									; ax = ax * 32
	xor dx, dx 									; clear dx
	div word [BytesPerSector] 	; ax = ax / bytes per sector
	
	test dx, dx 								; checking if the division was exact
	jz .root_dir_after
	inc ax 											; add 1 to ax if the division was not exact

.root_dir_after:

	; reading the root directory
	; setting the parameters
	mov cl, al 									; cl = number of sectors to read
	pop ax 											; load the LBA address of the first sector of the root directory
	mov dl, [DriveNumber] 			; dl = drive number
	mov bx, buffer 							; es:bx = address to store the read data
	call disk_read

	; search for the kernel.bin
	xor bx, bx 									; bx = 0
	mov di, buffer 							; es:di = address of the root directory (di points to filename as it is the first entry)


.search_kernel:
	mov si, file_kernel_bin 		; ds:si = address of the kernel.bin filename
	mov cx, 11 									; cx = length of the filename
	push di 										; save di
	repe cmpsb 									; compare the filename with the kernel.bin filename (compares files at ds:si and es:di)
	pop di 											; restore di
	je .found_kernel 						; if the filenames match, then jump to .found_kernel

	; if the filenames don't match, then check the next entry
	add di, 32 									; move to the next entry (each entry is 32 bytes long)
	inc bx 											; increment bx to check if we have reached the end of the root directory
	cmp bx, [RootEntries] 			; compare bx with the total number of entries in the root directory
	jl .search_kernel 					; if bx is less than the total number of entries, then jump to .search_kernel

	; if the kernel.bin file is not found, then print error message and halt the system
	jmp kernel_not_found_error

.found_kernel:
	; di points to the address of the kernel.bin file
	mov ax, [di + 26] 					; ax = first logical cluster number of the kernel.bin file (offset 26)
	mov [kernel_cluster], ax 		; store the first logical cluster number of the kernel.bin file

	; loading FAT from disk to memory
	; setting the parameters
	mov ax, [ReservedSectors] 		; ax = reserved sectors
	mov bx, buffer 							; es:bx = address to store the read data
	mov cl, [SectorsPerFAT] 			; cl = sectors per FAT
	mov dl, [DriveNumber] 			; dl = drive number
	call disk_read

	; reading the kernel.bin file using the FAT chain
	mov bx, KERNEL_LOAD_SEGMENT
	mov es, bx 									; es = segment to load the kernel.bin file
	mov bx, KERNEL_LOAD_OFFSET 	; bx = offset to load the kernel.bin file


.load_kernel_loop:
	; Reading the next cluster
	mov ax, [kernel_cluster] 		; ax = current cluster number
	; temporarily harding the offset to 31
	add ax, 31 									; 1st cluster=(kernel_cluster-2)*sectors_per_cluster+kernel_cluster

	mov cl, 1 									; cl = number of sectors to read
	mov dl, [DriveNumber] 			; dl = drive number
	call disk_read

	add bx, [BytesPerSector] 		; increment bx by the number of bytes read

	; computing the next cluster

	mov ax, [kernel_cluster] 		; ax = current cluster number
	; fatIndex = current cluster number * 1.5
	mov cx, 3 									
	mul cx 											
	mov cx, 2 									
	div cx 											; ax = fatIndex, dx = cluster mod 2

	mov si, buffer 							
	add si, ax 									; ds:si = address of the FAT entry of the current cluster
	mov ax, [ds:si] 						; ax = value of the FAT entry of the current cluster	

	; logic for reading 12 bit FAT entries
	or dx, dx 									
	jz .even 					

.odd:
	shr ax, 4										; shifting 4 bits in the odd case
	jmp .next_cluster_after	

.even:
	and ax, 0FFFh 							; masking the upper 4 bits in the even case
	
.next_cluster_after:
	cmp ax, 0FF8h 							; checking if the next cluster is the last cluster
	jae .read_finish

	; if the next cluster is not the last cluster, then load the next cluster
	mov [kernel_cluster], ax 		; store the next cluster number
	jmp .load_kernel_loop


.read_finish:

	; jumping to the kernel
	mov dl, [DriveNumber] 			; setting back the drive number

	mov ax, KERNEL_LOAD_SEGMENT ; setting the segment registers
	mov ds, ax
	mov es, ax

	jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

	jmp wait_for_key_and_reboot	; if the jump fails, then halt the system


	cli 								; clear interrupts, so CPU can't leave halt state
	hlt


;
; Error handling
;


kernel_not_found_error:
	mov si, msg_kernel_not_found
	call puts
	jmp wait_for_key_and_reboot


floppy_error:
	mov si, msg_read_failed
	call puts
	jmp wait_for_key_and_reboot


wait_for_key_and_reboot:
	mov ah, 0
	int 16h
	jmp 0FFFFh:0  				;  Jump to the beginning of BIOS memory which will reboot the system	


.halt:
	cli 									; clear interrupts, so CPU can't leave halt state
	hlt 									; halt the CPU


;
; Prints a string to the screen.
; Params:
; 	- ds:si points to string
;
puts:
	; saving the registers we will modify
	push si
	push ax

.loop:
	lodsb         ; loads the next byte(character) in al
	or al, al     ; verifies if the next character is null (OR on the same register will set the null flag if the value is null)
	jz .done

	mov ah, 0x0e  ; call the bios interrupt
	mov bh, 0     ; set the page to 0th page
	int 0x10
	
	jmp .loop

.done:
	pop ax
	pop si
	ret



;
; Disk routines
;


;
; Conversts LBA to CHS
; Params:
; 	- ax: the logical block address
; Returns:
;		- cx [bits 0-5]: sector number
; 	- cx [bits 6-15]: cylinder number
; 	- dh: head number
lba_to_chs:

	push ax											; save ax
	push dx											; save dx

	xor dx, dx									; clear dx to 0
	div word [SectorsPerTrack]	; ax = quotient: (LBA / SectorsPerTrack)
															; dx = remainder: (LBA % SectorsPerTrack)

	inc dx											; dx = remainder + 1
	mov cx, dx 									; cx = sector number


	xor dx, dx									; clear dx to 0
	div word [HeadsPerCylinder]	; ax = quotient: (LBA / SectorsPerTrack) / HeadsPerCylinder 
															; dx = remainder: (LBA / SectorsPerTrack) % HeadsPerCylinder
	mov dh, dl									; dh = head number
	mov ch, al									; ch = cylinder number (lower 8 bits)
	shl ah, 6										 
	or cl, ah										; finally cx = cylinder number (first 10 bits) + sector number

	pop ax											
	mov dl, al 									; restore dl
	pop ax											
	ret


;
; Reads Sector from a disk
; Params:
; 	- ax: LBA address
; 	- cl: number of sectors to read (upto 128)
; 	- dl: drive number
; 	- es:bx: address to store the read data
disk_read:

	push ax 										; save all modified registers
	push bx
	push cx
	push dx
	push di

	push cx 										; save cx
	call lba_to_chs							; convert LBA to CHS
	pop ax

	mov ah, 02h

	; Doing the read 3 times to avoid any errors
	mov di, 3

.retry:
	pusha 											; save all registers, since we don't know what BIOS will modify
	stc 												; set the carry flag
	int 13h 										; disk access interrupt to read sectors
	jnc .done 									; if carry flag is cleared, then the read was successful

	; if read failed
	popa 												; restore all registers
	call disk_reset

	dec di
	test di, di
	jnz .retry


.fail:
	jmp floppy_error

	
.done:
	popa 												; restore all registers

	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret


;
; Resets the disk
; Params:
; 	- dl: drive number
;
disk_reset:
	pusha 											; save all registers
	mov ah, 0 								; reset disk interrupt
	stc 												; set the carry flag
	int 13h 										; disk access interrupt to reset disk
	jc floppy_error 						; if carry flag is set, then the reset failed
	popa  											; restore all registers
	ret



msg_loading: 					db 'Loading...', ENDL, 0
msg_read_failed: 			db 'Read from the disk failed', ENDL, 0
msg_kernel_not_found: db 'Stage2 file not found', ENDL, 0
file_kernel_bin: 			db 'STAGE2  BIN'
kernel_cluster: 			dw 0

KERNEL_LOAD_SEGMENT 	equ 0x2000
KERNEL_LOAD_OFFSET 		equ 0

times 510-($-$$) db 0   ;  Pad the first 510 bytes with zero and then the code. Size of the code segment is given by ($-$$)
dw 0AA55h               ;  A word is 2 bytes


buffer: