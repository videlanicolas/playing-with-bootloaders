;
; Bootloader that prepares the GDT and switches from 16 bit real mode to 32 bit protected mode.
;
[org 0x7c00]    ; This is where BIOS loads us.

jmp $           ; Loop forever.

%include "./src/common/print_string_pm.asm"

; Spacing and signature
times 510 - ($ - $$) db 0   ; This line basically adds 0x00 bytes to fill up until 510 bytes.
dw 0xaa55                   ; Magic number for BIOS to detect that this sector is a bootloader.