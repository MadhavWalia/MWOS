org 0x0   ;  Start the offset from the given address
bits 16      ;  Emit 16-bit code (done for backward compatibilty)


%define ENDL 0x0D, 0x0A    ; Macro for \n (hex for the line feed(\) and carrige return (n))


start:
	; print message
	mov si, msg_hello
	call puts

.halt:
	cli
	hlt


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
	pop bx
	pop ax
	pop si
	ret


msg_hello: db 'Hello from the kernel side, I think I have been booted right', ENDL, 0
