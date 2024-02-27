[org 0x7c00]    ; BIOS loads us at this address, so shift all addresses by this amount.

mov bx, HELLO_WORLD
call print_string

jmp $           ; Jump forever.

%include "./src/common/print_string.asm"

; Global data

HELLO_WORLD: db "Hello World!", 0   ; Just a blob of bytes that match the string, plus the NULL byte.

; spacing and signature
times 510 - ($ - $$) db 0   ; This line basically adds 0x00 bytes to fill up until 510 bytes.
dw 0xaa55                   ; Magic number for BIOS to detect that this sector is a bootloader.