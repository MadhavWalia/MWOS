bits 16

section _TEXT class=CODE

; Written in lieu of the _cdecl calling convention

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