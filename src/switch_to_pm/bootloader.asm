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

; In this section of our routine we're going to define the GDT and load the GDT register.
; In Real Mode we must address memory linearly, e.g.: 0x7000, 0x7001, etc...
; This is not the case in Protected Mode, we address the memory by "Segments" or "Pages".
; A "Segment" is a portion of memory (it can be 1 byte up to 16 MiB in size, length defined by 24 bits), 
; they have extra attributes we can define to mark them as "read-only" or given them different levels
; of privilege. This is the "protected mode" feature we're looking to enable.
; Segments can overlap each other. For this example we're going to overlap them, to simplify things.
; We don't care about "Pages" here, we'll care about them afterwards when we load our Kernel.
;
; All entries of the GDT are 8 bytes long. Check https://osdev.org/Global_Descriptor_Table
; for a description on how this table is defined.
gdt_start:

; We're going to have two segments: A code segment (where our executable code will live) and a data
; segment (where our variables will live, but no code will be executed here). 

; The first segment must always be the NULL segment, which are 8 0x00 bytes. This is required as said in Intel's
; x86 manual.

; NULL segment.
dq 0            ; Assembler has 'dq' (define quad word) which defines 8 bytes.

; Code segment.
gdt_code:
; First double word. This contains the first part of the limit (16 bits) and the first part of the base address (16 bits).
dw 0xffff       ; The first word defines the first 16 bit for our segment's limilt, we aim to make it as long as possible
                ; so mark all 1s.
dw 0            ; The second word defines the first 16 bit of our segment's base address in physical memory. We're going to
                ; use all the available memory, so make it 0.

; Second double word. This contains many things, which will be detailed as we define them.
db 0            ; The first 8 bits are part of the base address' bits.

; This is the Access byte, and is made up of:
; 0: Accessed bit: The CPU will set it when the segment is accessed. We are not going to use it, so make it 0.
; 1: Read-write bit: For Code segments this only controls read (1 - allowed, 0 - not allowed), you can't write to code segments.
;                    We're going to allow reads to the code segment, because it'll be easier to handle later.
; 2: Direction/Conforming bit: 
;                    For Code Segments the ring (https://osdev.org/Security#Rings) this code is allowed to execute.
;                    A value of 0 means it only allows execution on the ring defined in this segment.
;                    A value of 1 means it allows code execution from higher rings (i.e. less privileged code). OSes don't like this
;                    so we set this to 0.
; 3: Executable bit: 0 if this is a Data segment, 1 if Code segment, so we choose 1.
; 4: Descriptor type bit: 0 if this is a system segment (like TSS), 1 if this is either code/data segment. So we set this to 1.
; 5-6: Descriptor privilege level: Contains the privilege level (i.e. Ring). We're going to use the highest privilege, so 0.
; 7: Present bit: Refers to a valid segment, always 1.
db 10011010b

; Next byte is made up of two things:
; 0-3: The last 4 bits of the segment's limit, we defined the base above. Mark this to 1111b
; 4-7: These are called "flags", made up of the following:
;      Reserved bit: should be marked 0.
;      Long-mode: 1 if this is a 64 bit segment, 0 for 32 bit segment. So we set this to 0.
;      Size: 0 for 16 bit protected mode, 1 for 32 bit protected mode. So set this to 1.
;      Granularity: Scaling factor for the segment's limit. If 0 then the limit is counted in bytes (byte granularity),
;                   if 1 then the limit is counted in 4KiB (page granularity). Set this to 1 so we get up to 4 GiB of limit.
db 11001111b

; The remaining byte are the remainig bits of our base address, so all 0s.
db 0

; Data segment
; Starts of the same as Code segment.
dw 0xffff       ; Set the first bits of limit. 
dw 0            ; Set the first bits of the base address.
db 0            ; Still the base address.

; Similar to the one in Code Segment, with some changes:
; 1: Read-write bit: For data segments, 0 disallows write and 1 allows write. Read is always guaranteed.
;                    We set this to 1 to make things simple
; 2: Direction/Confirming bit: For data segments, 0 means the segment grows up, 1 if grows down. We want to expand down.
; 3: Executable bit: 1 for Code segment, 0 for Data segment, so clear this bit.
db 10010010b

; The next byte is exactly the same as the one in Code Segment.
db 11001111b

; The last byte are the remaining bits of the base address.
db 0

gdt_end:

; In order for the CPU to learn where this GDT is located, we need to create a GDT descriptor table.
; This is a 48 bit structure.
gdt_desc:
    db gdt_end - gdt_start  ; Size of the entire GDT. We use labels here and let NASM calculate it for us.
    dw gdt_start            ; Address of the start of the GDT.

; Load the GDT descriptor
lgdt [gdt_desc]

; We can't alter CR0 directly, so instead load it to EAX, modify it and load it back to CR0. 
mov eax, cr0
or eax, 1           ; We need to set bit 0 (Protection Enable, the thing that switches to protected mode).
mov cr0, eax

; At this poit we have everything ready to switch to protected mode, but it's not enabled just yet.
; The CPU does a thing called "pipelining", more details here: https://en.wikipedia.org/wiki/Instruction_pipelining
; Essetially it's tryinng to be efficient when executing instructions. The CPU has to fetch the next instruction,
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
%include "./src/common/print_string_pm.asm"

[bits 32]

protected_mode_start:

; Now in protected mode!
; CS (Code segment register) has been set by the CPU

; Print a message saying we're in protected mode now.
mov ebx, PM_MSG
call print_string_pm

jmp $       ; Loop forever, in protected mode.

; Data
REAL_MODE_MSG: db "Hello from real mode! We're in 16 bit land", 0x0d, 0x0a, 0
PM_MSG: db "Hello from protected mode! We're in 32 bit land now!", 0x0d, 0x0a, 0
A20_DISABLED_MSG: db "A20 is disabled! Callig BIOS to enable it...", 0x0d, 0x0a, 0
A20_ENABLED_MSG: db "A20 enabled!", 0x0d, 0x0a, 0

; Spacing and signature
times 510 - ($ - $$) db 0   ; This line basically adds 0x00 bytes to fill up until 510 bytes.
dw 0xaa55                   ; Magic number for BIOS to detect that this sector is a bootloader.