bits 16

section _ENTRY class=CODE

extern _cstart_
global entry

entry:
		cli
		mov ax, ds
		mov ss, ax
		mov sp, 0
		mov bp, sp
		sti

		; expecting the boot drive to be in dl. Sending it as a parameter to cstart
		xor dh, dh			; clearing dh as boot drive is only in dl
		push dx 			  ; pushing dx as parameter to cstart
		call _cstart_

		; if cstart returns, halt the system
		cli
		hlt