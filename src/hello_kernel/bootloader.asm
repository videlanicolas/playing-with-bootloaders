;
; Bootloader for our first Kernel.
;

[org 0x7c00]        ; BIOS loads us at this address, so shift all addresses by this amount.

KERNEL_OFFSET equ 0x1000        ; This is the offset form 0x7c00 that we choose for loading our kernel code.

mov [BOOT_DRIVE], dl            ; BIOS loads the boot drive in DL, so let's store it for later.

; Prepare the stack.
mov bp, 0x9000  ; Set the base of our stack to a far away value.
mov sp, bp      ; Match the start and base of our stack.

; Send a message to the user saying we're in real mode. We'll jump to protected mode afterwards.
mov bx, REAL_MODE_MSG
call print_string

; First thing is to load the Kernel in memory. The Kernel is located at the sectors right after the bootloader.
mov bx, KERNEL_LOAD_MSG     ; Show nice message to the user.
call print_string

mov bx, KERNEL_OFFSET       ; Address we want our Kernel to be loaded. We pass 0x1000 but physically it's address 0x7c00 + 0x1000.
mov dh, 15                  ; Read 15 sectors.
mov dl, [BOOT_DRIVE]        ; It's not necessary to do this step because we know we didn't modified DL before, but given this is an example
                            ; and for demonstration purposes (we're not looking to be space/time efficient) we can add this step.
call disk_load

cmp ah, 0       ; If AH is not zero then something went wrong. Don't read from memory and jump to the infinite loop.
jne end

end:

mov bx, FAIL_BOOT_MSG     ; Indicate the user that there was an error.
call print_string

jmp $           ; If we reached this point we failed to boot. This is here to prevent executing the bytes below
                ; as part of the main routine.

%include "./src/common/print_string.asm"
%include "./src/common/disk_load.asm"

; Data
BOOT_DRIVE: db 0
REAL_MODE_MSG: db "We're in 16 bit Real Mode, switching to 32 bit Protected Mode.", 0x0d, 0x0a, 0
KERNEL_LOAD_MSG: db "Loading Kernel.", 0x0d, 0x0a, 0
FAIL_BOOT_MSG: db "Error booting!", 0

; Let's first load the Kernel in memory. Usually Kernels are shipped with the bootloader on top, so the sections immediately
; after the bootloader will contain the Kernel code. For this example the Kernel is small enough that it fits in
; one sector, so we only need to load one sector to memory.

; Spacing and signature
times 510 - ($ - $$) db 0   ; This line basically adds 0x00 bytes to fill up until 510 bytes.
dw 0xaa55                   ; Magic number for BIOS to detect that this sector is a bootloader.