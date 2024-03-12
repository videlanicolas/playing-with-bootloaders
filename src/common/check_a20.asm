; Check if A20 is enabled (returns 1 in AX) or disabled (returnns 0 in AX).
;
; So, this is weird...
; Apparently there was a bug on Intel 80286 chips. These chips could address 16 MiB instead of 1 MiB from 8086,
; and was the first of the x86 family to support "protected mode".
; The 8086 has a bus of 20 lines (A0 to A19), so any address above 1 MiB wraps around to 0. Programmers of this chip
; took this as a feature of the chip rather than a limitation and programmed software that took advantage of this
; wrap around.
; Intel 80826 chips had to stay compatible with 8086 programs, so they needed to emulate this somehow. Given that
; this chip has a larger bus (24 bits, so A0 to A23) when 8086 programs (that took advantage of its memory looping
; feature) were loaded in 80826 it caused a problem becasue A20 would not wrap around the bit to A0.
; So engineers at Intel proposed marking the A20 line in the bus to 0, making 8086 programs work on this new chip.
; They added a physical pin to control this bus line.
;
; This means that today we have to deal with this issue. While it's not a problem when we're in 16 bit world, it is
; a problem if we want to switch to 32 bits. We need to enable the A20 line so we can address all memory available.
; When the computer boot, A20 is disabled. Some BIOSes (and emulators like QEMU) enable it for us (checkout 
; https://github.com/qemu/qemu/blob/05ec974671200814fa5c1d5db710e0e4b88a40af/roms/config.seabios-128k#L24). Some bootloaders
; as well (GRUB: https://git.savannah.gnu.org/cgit/grub.git/tree/grub-core/boot/i386/qemu/boot.S?id=e62ca2a870ecec4d46fcc03556e8e61592e9dd18#n53).
;
; But we must always check! So how could one check this?
;
; Given that the feature is that memory wraps around, we could have two addresses that with A20 disabled would 
; wrap around. If A20 is enabled, those two addresses will point to different parts of the memory space, and thus
; will contain different values.
[bits 16]

check_a20:
    pushf           ; Push FLAGS to the stack. This is the register that contains flags such as carry, parity, zero, sign, etc.
    push ds         ; Save the state of Data Segment register.
    push si         ; Save the state of Source Index register.
    push es         ; Save the state of Extra Segment register.
    push di         ; Save the state of Destination Index register.

    cli             ; Disable all interrupts.

    ; We're going to check two addresses: [ES:DI] and [DS:SI]. These are the Extra Segment and Data Segment segments, with their
    ; respective offsets. In order to calculate the physical address in real mode using segments, the CPU calculates the physical
    ; address like so: segment * 16 + offset.
    ;
    ; So, if A20 is disabled then the address 0x00500 will hold the same data as 0x100500 (0x0500 as an example).
    ; That means ES:DI = 0x0000:0x0500 and DS:SI = 0xFFFF:0x0510.
    ; 
    ; 0x0000 * 16 = 0x0000 -> 0x0000 + 0x0500 = 0x000500
    ; 0xFFFF * 16 = 0xFFF0 -> 0xFFF0 + 0x0510 = 0x100500
    xor ax, ax      ; This makes AX = 0. It's faster to do this operation than 'mov ax, 0' (which takes 5 bytes and more cycles).
    mov es, ax