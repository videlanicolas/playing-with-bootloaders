; In this section we're going to define the GDT and load the GDT register.
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
[bits 16]

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

gdt_data:
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
    dw gdt_end - gdt_start - 1  ; Size of the entire GDT. We use labels here and let NASM calculate it for us.
    dd gdt_start                ; Address of the start of the GDT.
