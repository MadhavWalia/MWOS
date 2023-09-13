bits 16

section _TEXT class=CODE

; Written in lieu of the _cdecl calling convention


;
; void _cdecl x86_div64_32
; args: dividend (64-bit), divisor (32-bit)
; returns: quotient (64-bit), remainder (32-bit)
;
global _x86_div64_32
_x86_div64_32:
    ; making a new stack frame (since we are in small memory mode, only the offset is needed)
    push bp                 ; save the old bp
    mov bp, sp              ; initialize the frame

    push bx                 ; saving bx

    ; Dividing in 32-bit chunks (using long division)
    mov eax, [bp + 8]       ; eax <- upper 32 bits of dividend (Because the value is stored in little endian)
    mov ecx, [bp + 12]      ; ecx <- divisor
    xor edx, edx            ; clearing edx

    div ecx                 ; eax <- quotient, edx <- remainder

    ; Saving the quotient (upper 32 bits)
    mov bx, [bp + 16]      ; (16-bit register required due to near pointer)
    mov [bx + 4], eax      

    ; Dividing the lower 32 bits
    mov eax, [bp + 4]       ; eax <- lower 32 bits of dividend
    div ecx                 ; eax <- quotient, edx <- remainder

    ; Saving the quotient (lower 32 bits)
    mov [bx], eax
    mov bx, [bp + 18]
    mov [bx], edx

    pop bx                  ; restoring bx

    ; restoring the old stack frame
    mov sp, bp              ; restore the stack pointer
    pop bp                  ; restore the old bp
    ret


;
; int 10h / ah=0Eh
; args: characters, page
;
global _x86_video_writeChar
_x86_video_writeChar:

    ; making a new stack frame (since we are in small memory mode, only the offset is needed)
    push bp             ; save the old bp
    mov bp, sp          ; initialize the frame

    ; saving bx
    push bx

    ; [bp + 0] - old stack frame
    ; [bp + 2] - return address (2 bytes for small memory mode)
    ; [bp + 4] - first argument (characters) (Note: bytes are converted to words to be able to push them on the stack)
    ; [bp + 6] - second argument (page)
    mov ah, 0Eh         ; set the function number
    mov al, [bp + 4]    ; set the character
    mov bh, [bp + 6]    ; set the page

    int 10h             ; call the interrupt

    ; restoring bx
    pop bx

    ; restoring the old stack frame
    mov sp, bp          ; restore the stack pointer
    pop bp              ; restore the old bp
    ret



;
; bool _cdelc x86_Disk_Reset
; args: drive (8 bits)
;
global _x86_Disk_Reset
_x86_Disk_Reset:

    ; making a new stack frame (since we are in small memory mode, only the offset is needed)
    push bp             ; save the old bp
    mov bp, sp          ; initialize the frame

    mov dl, [bp + 4]    ; set the drive number
    mov ah, 00h           ; set the function number to reset disk
    stc                 ; set the carry flag
    int 13h             ; call the interrupt

    mov ax, 1
    sbb ax, 0           ; success for 1, failure for 0

    ; restoring the old stack frame
    mov sp, bp          ; restore the stack pointer
    pop bp              ; restore the old bp
    ret


;
; bool _cdelc x86_Disk_Read
; args: drive (8 bits), cylinder (16 bits), head (16 bits), sector (16 bits), dataOut (16-bit far pointer)
;
global _x86_Disk_Read
_x86_Disk_Read:

    ; making a new stack frame (since we are in small memory mode, only the offset is needed)
    push bp             ; save the old bp
    mov bp, sp          ; initialize the frame

    push bx             ; saving bx
    push es             ; saving es

    ; Input arguments setup:
    mov dl, [bp + 4]    ; set the drive number

    mov ch, [bp + 6]    ; set the cylinder number
    mov cl, [bp + 7]
    shl cl, 6

    mov dh, [bp + 8]    ; set the head number

    mov al, [bp + 8]    ; set the sector number
    and al, 0x3F
    mov cl, al

    mov al, [bp + 12]   ; number of sectors to read

    mov bx, [bp + 16]   ; set the dataOut pointer
    mov es, bx
    mov bx, [bp + 14]

    ; Call the interrupt
    mov ah, 02h           ; set the function number to read disk
    stc
    int 13h

    ; Set the return value
    mov ax, 1
    sbb ax, 0           ; success for 1, failure for 0

    pop es              ; restoring es
    pop bx              ; restoring bx

    ; restoring the old stack frame
    mov sp, bp          ; restore the stack pointer
    pop bp              ; restore the old bp
    ret


;
; bool _cdelc x86_Disk_GetDriveParameters
; args: drive (8 bits), driveTypeOut (8 bit pointer), 
;       cylindersOut (16 bit pointer), sectorsOut (16 bit pointer), headsOut (16 bit pointer)
;
global _x86_Disk_GetDriveParameters
_x86_Disk_Reset:

    ; making a new stack frame (since we are in small memory mode, only the offset is needed)
    push bp             ; save the old bp
    mov bp, sp          ; initialize the frame

    push es             ; saving es
    push bx             ; saving bx
    push si             ; saving si
    push di             ; saving di

    mov dl, [bp + 4]    ; set the drive number

    mov ah, 08h         ; set the function number to get drive parameters
    mov di, 0
    mov es, di          ; set the es:di pointer to 0:0
    stc                 ; set the carry flag
    int 13h             ; call the interrupt

    mov ax, 1
    sbb ax, 0           ; success for 1, failure for 0

    ; output arguments setup
    mov si, [bp + 6]    ; driveTypeOut
    mov [si], bl

    mov bl, ch          ; cylindersOut - lower 8 bits
    mov bh, cl          ; cylindersOut - upper 2 bits (6-7)
    shr bh, 6
    mov si, [bp + 8]   
    mov [si], bx  

    xor ch, ch
    and cl, 0x3F        ; sectorsOut - lower 6 bits
    mov si, [bp + 10]
    mov [si], cx

    mov cl, dh          ; headsOut
    mov si, [bp + 12]
    mov [si], cx

    pop di              ; restoring di
    pop si              ; restoring si
    pop bx              ; restoring bx
    pop es              ; restoring es

    ; restoring the old stack frame
    mov sp, bp          ; restore the stack pointer
    pop bp              ; restore the old bp
    ret
