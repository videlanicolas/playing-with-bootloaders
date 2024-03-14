;
; Bootloader that prepares the GDT and switches from 16 bit real mode to 32 bit protected mode.
;
[org 0x7c00]    ; This is where BIOS loads us.

; Prepare the stack.
mov bp, 0x9000  ; Set the base of our stack to a far away value.
mov sp, bp      ; Match the start and base of our stack.

; Send a message to the user saying we're in real mode. We'll jump to protected mode afterwards.
mov bx, REAL_MODE_MSG
call print_string

;
; In order to switch to protected mode we need to do the following:
; 1. Disable all hardware nterrupts.
; 2. Enable the A20 line (https://osdev.org/A20_Line). QEMU does this for us luckily, but we should check that this is actually the case.
; 3. Load the GDT.
;

cli             ; Disable all hardware interrupts while we switch to protected mode.

; Check if A20 is enabled. Enable it through a BIOS interrupt if not.
call check_a20
cmp ax, 1
je load_gdt     ; If the routine said A20 is enabled, continue normally to load the GDT, we don't need to do anything else.

; Ah interesting, if code reaches this point then A20 is disabled. Let's print a message to inform the user.
mov bx, A20_DISABLED_MSG
call print_string

call enable_a20
jb fail_to_boot     ; If CF is set then there was a problem enabling A20.

; Nice! A20 was enabled, let's verify.
call check_a20
cmp ax, 1
jne fail_to_boot        ; If AX returned with a value other than 1, this means A20 is disabled. Fail booting.

load_gdt:
jmp $
; lgdt [GDTR]     ; Load the GDT register with the start address of the Global Descriptor Table.

; We can't alter CR0 directly, so instead load it to EAX, modify it and load it back to CR0. 
mov eax, cr0
or eax, 1           ; We need to set bit 0 (Protection Enable, the thing that switches to protected mode).
mov cr0, eax

fail_to_boot:

jmp $           ; Loop forever. We should arrive here only if there was a problem enabling protected mode.

%include "./src/common/print_string.asm"
%include "./src/common/check_a20.asm"
%include "./src/common/enable_a20.asm"
%include "./src/common/print_string_pm.asm"

[bits 32]

protected_mode_start:

; Print a message saying we're in protected mode now.
mov ebx, PM_MSG
call print_string_pm

jmp $       ; Loop forever, in protected mode.

; Data
REAL_MODE_MSG: db "Hello from real mode! We're in 16 bit land",  0x0d, 0x0a, 0
PM_MSG: db "Hello from protected mode! We're in 32 bit land now!", 0x0d, 0x0a, 0
A20_DISABLED_MSG: db "A20 is disabled! Callig BIOS to enable it...", 0x0d, 0x0a, 0

; Spacing and signature
times 510 - ($ - $$) db 0   ; This line basically adds 0x00 bytes to fill up until 510 bytes.
dw 0xaa55                   ; Magic number for BIOS to detect that this sector is a bootloader.