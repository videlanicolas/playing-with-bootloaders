;
; Bootloader for our first Kernel.
;
[bits 16]

[org 0x7c00]        ; BIOS loads us at this address, so shift all addresses by this amount.

KERNEL_OFFSET equ 0x1000        ; This is the offset form 0x7c00 that we choose for loading our kernel code.

mov [BOOT_DRIVE], dl            ; BIOS loads the boot drive in DL, so let's store it for later.

; Prepare the stack.
mov bp, 0x9000  ; Set the base of our stack to a far away value.
mov sp, bp      ; Match the start and base of our stack.

; Send a message to the user saying we're in real mode. We'll jump to protected mode afterwards.
mov bx, REAL_MODE_MSG
call print_string

; Let's first load the Kernel in memory. Usually Kernels are shipped with the bootloader on top, so the sections immediately
; after the bootloader will contain the Kernel code. For this example the Kernel is small enough that it fits in
; one sector, so we only need to load one sector to memory.
mov bx, KERNEL_LOAD_MSG     ; Show nice message to the user.
call print_string

mov bx, KERNEL_OFFSET       ; Address we want our Kernel to be loaded. We pass 0x1000 but physically it's address 0x7c00 + 0x1000.
mov dh, 15                  ; Read 15 sectors.
mov dl, [BOOT_DRIVE]        ; It's not necessary to do this step because we know we didn't modified DL before, but given this is an example
                            ; and for demonstration purposes (we're not looking to be space/time efficient) we can add this step.
call disk_load
cmp ah, 0       ; If AH is not zero then something went wrong. Don't read from memory and jump to the infinite loop.
jne boot_fail

; Now let's jump to 32 bit pm mode.
cli             ; Disable all hardware interrupts while we switch to protected mode. We should re-enable them afterwards.

; Check A20 is enabled.
mov ax, 2402h
int 15h
jb boot_fail            ; BIOS sets CF to 1 if there was an error, so terminate this routine if so. JB is Jump if below, which actually checks if CF = 1.
cmp ah, 0               ; If A20 is enabled then this is 0.
jne load_gdt

; Enable A20.
mov bx, ENABLE_A20_MSG
call print_string

mov ax, 2401h
int 15h
jb boot_fail            ; If CF is set then this operation failed.
cmp ah, 0               ; If AH is different than 0 then the BIOS failed to enable A20.
jne boot_fail

; We load the GDT.
load_gdt:

mov bx, LOAD_GDT_MSG
call print_string

; Load the GDT descriptor.
lgdt [gdt_desc]

; We can't alter CR0 directly, so instead load it to EAX, modify it and load it back to CR0. 
mov eax, cr0
or eax, 1               ; We need to set bit 0 (Protection Enable, the thing that switches to protected mode).
mov cr0, eax

; Far jump to clear the CPU pipeline.
jmp 08h:protected_mode_start

boot_fail:

mov bx, FAIL_BOOT_MSG     ; Indicate the user that there was an error.
call print_string

jmp $           ; If we reached this point we failed to boot. This is here to prevent executing the bytes below
                ; as part of the main routine.

; Data.
BOOT_DRIVE: db 0
REAL_MODE_MSG: db "16 bit Real Mode.", 0x0d, 0x0a, 0
KERNEL_LOAD_MSG: db "Loading Kernel.", 0x0d, 0x0a, 0
ENABLE_A20_MSG: db "Enabling A20.", 0x0d, 0x0a, 0
LOAD_GDT_MSG: db "Loading GDT.", 0x0d, 0x0a, 0
FAIL_BOOT_MSG: db "Error booting!", 0

%include "./src/common/disk_load.asm"
%include "./src/common/load_gdt.asm"

[bits 32]

protected_mode_start:

mov ax, 10h         ; NULL is at 0x00, CS is at 0x08, 8 bytes more and we get the data segment at 0x10.
mov ds, ax          ; Make the Data Segment = 0x10.
mov ss, ax          ; Also make the stack segment equal to the data segment.
mov es, ax          ; Make the Extra Segment equal to the data segment as well.

mov esp, 090000h    ; ESP is the stack pointer in 32 bit world. Set it to a far away value (+1 MiB, which

mov ebx, PM_MODE_MSG
call print_string_pm

; Call our Kernel from it's Main function, which should be (physically) at 0x7c00 + 0x1000.
call KERNEL_OFFSET

jmp $           ; Safeguard to not execute the code below.

%include "./src/common/print_string_pm.asm"

PM_MODE_MSG: db "32 bit Protected Mode on.", 0

; Spacing and signature
times 510 - ($ - $$) db 0   ; This line basically adds 0x00 bytes to fill up until 510 bytes.
dw 0xaa55                   ; Magic number for BIOS to detect that this sector is a bootloader.