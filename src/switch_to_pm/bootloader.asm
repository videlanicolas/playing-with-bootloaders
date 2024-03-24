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

cli             ; Disable all hardware interrupts while we load thhe GDT.

; Disable A20, just to double check our manual check works.
mov ax, 2400h   ; Service to disable A20 bus line.
int 15h         ; Call BIOS.

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

; Let the user know that we enabled A20.
mov bx, A20_ENABLED_MSG
call print_string

load_gdt:

xor ax, ax
mov ds, ax

; Load the GDT descriptor.
lgdt [gdt_desc]

; We can't alter CR0 directly, so instead load it to EAX, modify it and load it back to CR0. 
mov eax, cr0
or eax, 1           ; We need to set bit 0 (Protection Enable, the thing that switches to protected mode).
mov cr0, eax

; At this point we have everything ready to switch to protected mode, but it's not enabled just yet.
; The CPU does a thing called "pipelining", more details here: https://en.wikipedia.org/wiki/Instruction_pipelining
; Esentially it's trying to be efficient when executing instructions. The CPU has to fetch the next instruction,
; decode it, execute it, access memory and write registers. The CPU can execute one instruction while fetching the
; one, and writing to memory for the execution results of the previous memory. This is good because it takes advantage
; of every clock cycle.
;
; But it means that at this point it has instructions pertaining to 16 bit world in the pipeline, from pasts and 
; future instructions. We can't have that when we switch to 32 bit, so we need to "clear the pipeline". But how do we do this?
; The CPU is good at predicting what actions are needed next when the instructions are easy enough, like "MOV", "ADD", "INC".
; But when the instruction is "JMP" or "CALL" the CPU has very little idea what the next instruction will be, so
; when either of these instructions is fetched by the CPU it doesn't fetch any further instruction until this current
; instruction finishes. This effectively clears the pipeline.
;
; But a near JMP is easy enough for the CPU to calculate what the next instruction will be, so to make sure we really
; clear the pipeline we need a "far jump". This means jumping to another segment.
; Given that the NULL segment is 00h, the next segment we defined (Code segment) is at 00h + 8 = 08h.
jmp 08h:protected_mode_start

fail_to_boot:

jmp $           ; Loop forever. We should arrive here only if there was a problem enabling protected mode.

%include "./src/common/print_string.asm"
%include "./src/common/check_a20.asm"
%include "./src/common/enable_a20.asm"
%include "./src/common/load_gdt.asm"

[bits 32]

protected_mode_start:

; Now in protected mode!
; The very first thing we need to do is to update all segment registers, because they currently have 
; data from 16 bit mode which we need to update for 32 bit mode.
; CS (Code segment register) has been set by the CPU, and should not be altered.
mov ax, 10h         ; NULL is at 0x00, CS is at 0x08, 8 bytes more and we get the data segment at 0x10.
mov ds, ax          ; Make the Data Segment = 0x10.
mov ss, ax          ; Also make the stack segment equal to the data segment.
mov es, ax          ; Make the Extra Segment equal to the data segment as well.

mov esp, 090000h    ; ESP is the stack pointer in 32 bit world. Set it to a far away value (+1 MiB, which
                    ; is far away from our bootloader and BIOS code).

; Print a message saying we're in protected mode now.
mov ebx, PM_MSG
call print_string_pm

jmp $       ; Loop forever, in protected mode.

; Data
REAL_MODE_MSG: db "Hello from real mode!", 0x0d, 0x0a, 0
PM_MSG: db "Hello from protected mode!", 0x0d, 0x0a, 0
A20_DISABLED_MSG: db "A20 is disabled! Callig BIOS to enable it...", 0x0d, 0x0a, 0
A20_ENABLED_MSG: db "A20 enabled!", 0x0d, 0x0a, 0

%include "./src/common/print_string_pm.asm"

; Spacing and signature
times 510 - ($ - $$) db 0   ; This line basically adds 0x00 bytes to fill up until 510 bytes.
dw 0xaa55                   ; Magic number for BIOS to detect that this sector is a bootloader.