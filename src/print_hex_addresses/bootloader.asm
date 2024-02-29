[org 0x7c00]    ; BIOS loads us at this address, so shift all addresses by this amount.

mov cx, 0x1fa5  ; Print this hex.
call print_hex

jmp $           ; Jump forever.

%include "./src/common/print_hex.asm"

; Spacing and signature
times 510 - ($ - $$) db 0   ; This line basically adds 0x00 bytes to fill up until 510 bytes.
dw 0xaa55                   ; Magic number for BIOS to detect that this sector is a bootloader.