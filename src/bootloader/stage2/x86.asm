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