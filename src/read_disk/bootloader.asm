;
; We're going to load something from disk.
;
[org 0x7c00]    ; BIOS loads us at this address, so shift all addresses by this amount.

mov [BOOT_DRIVE], dl            ; BIOS loads the boot drive in DL, so let's store it for later.

; Get the stack ready.
; Our bootloader is at 0x7c00. Given we're going to write 1 KiB of data after, that's 512 words plus another 512 words
; from our bootloader.
; 0x7c00 + 512 + 512 = 0x7cx00 + 0x0200 + 0x0200 = 0x8000
mov bp, 0x8000  ; We'll place the base of our stack at 0x8000 and let it grow from there.
mov sp, bp      ; Make the stack start at the base.

; We're going to load 5 sectors from disk, that's 5 * 512 = 2.5 KiB.
; The data will be stored at ES:BX, and we'll pick a value far away from our stack.
mov bx, 0x9000  ; 0x9000 is far away from the base of our stack, we're not going to use that much really.
mov dh, 57       ; Read 5 sectors.
call disk_load

cmp ah, 0       ; If AH is not zero then something went wrong. Don't read from memory and jump to the infinite loop.
jne end

; If we're here the we successfully read the disk!
; Print out the contents of the data at 0x9000.
mov bx, SUCCESS_LOAD
call print_string

mov bx, FIRST_MSG
call print_string
mov cx, [0x9000]
call print_hex      ; This should print "0xdead".

; Let's print the first word of the second sector.
mov bx, SECOND_MSG
call print_string
mov cx, [0x9000 + 512]
call print_hex      ; This should print "0xbeef".

end:

jmp $           ; Jump forever.

%include "./src/common/disk_load.asm"

; Data
BOOT_DRIVE: db 0
SUCCESS_LOAD: db "Loaded 5 sectors to memory.", 0x0d, 0x0a, 0
FIRST_MSG: db "Word at 0x9000: ", 0
SECOND_MSG: db 0x0d, 0x0a, "Word at 0x9200: ", 0

; Spacing and signature
times 510 - ($ - $$) db 0   ; This line basically adds 0x00 bytes to fill up until 510 bytes.
dw 0xaa55                   ; Magic number for BIOS to detect that this sector is a bootloader.

; After the first sector (sector 1) we'll have 
times 256 dw 0xdead
times 256 dw 0xbeef