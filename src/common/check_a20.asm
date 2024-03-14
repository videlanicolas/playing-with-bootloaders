; Check if A20 is enabled (returns 1 in AX) or disabled (returns 0 in AX).
;
; So, this is weird...
; This problem came with the introduction of Intel 80286 chips. These chips could address 16 MiB instead of 1 MiB ( like in 8086),
; and was the first of the x86 family to support "protected mode".
; The 8086 has a 20 line bus (A0 to A19), so any address above 1 MiB (2**20) wraps around to 0. Programmers of this chip
; took this as a feature rather than a limitation and programmed software that took advantage of this wrap around.
;
; Intel 80286 chips had to stay compatible with 8086 programs, so they needed to emulate this wrap around memory feature somehow. Given that
; this chip has a larger bus (24 bits, so A0 to A23) when 8086 programs (that took advantage of its memory looping
; feature) were loaded in 80286 it caused a problem becasue A20 would not be 0 and carry over the carry bit.
; So engineers at Intel proposed forcing the A20 line in the bus to 0, making 8086 programs work on this new chip.
; They added a physical pin to enable/disable this.
;
; This means that today we have to deal with this issue. While it's not a problem when we're in 16 bit world (since we only
; need 20 bus lines, 16 + 4 for extended addressig), it is a problem if we want to switch to 32 bits.
; We need to enable the A20 line so we can address all memory available.
; When the computer boots, A20 is disabled. Some BIOSes (and emulators like QEMU) enable it for us (checkout 
; https://github.com/qemu/qemu/blob/05ec974671200814fa5c1d5db710e0e4b88a40af/roms/config.seabios-128k#L24). Some bootloaders
; as well (GRUB: https://git.savannah.gnu.org/cgit/grub.git/tree/grub-core/boot/i386/qemu/boot.S?id=e62ca2a870ecec4d46fcc03556e8e61592e9dd18#n53).
;
; But we must always check! So how could one check this?
;
; The BIOS provides interrupt 15h with services to check this, but that's the boring way of checking.
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

    ; We already disabled hardware interrupts, so no need to do that here.

    ; We're going to check two addresses: [ES:DI] and [DS:SI]. These are the Extra Segment and Data Segment segments, with their
    ; respective offsets. In order to calculate the physical address in real mode using segments, the CPU calculates the physical
    ; address like so: segment * 16 + offset.
    ;
    ; So, if A20 is disabled then the address 0x000500 will hold the same data as 0x100500 (0x000500 as an example).
    ; That means ES:DI = 0x0000:0x0500 and DS:SI = 0xFFFF:0x0510.
    ; 
    ; 0x0000 * 16 = 0x0000 -> 0x0000 + 0x0500 = 0x000500
    ; 0xFFFF * 16 = 0xFFF0 -> 0xFFF0 + 0x0510 = 0x100500

    ; Makig ES:DI
    xor ax, ax      ; This makes AX = 0. It's faster to do this operation than 'mov ax, 0' (which takes 5 bytes and more cycles).
    mov es, ax      ; Make ES = 0x0000
    mov di, 0x0500  ; DI = 0x0500

    ; Making DS:SI
    not ax          ; AX was 0x0000, so now it's 0xFFFF.
    mov ds, ax      ; Now DS = 0xFFFF
    mov si, 0x0510  ; SI = 0x0510

    ; We're going to modify the last two bytes of ES:DI and DS:SI.
    ; We need to make sure these bytes hold the same value after out routine ends, if not we would've changed their
    ; value, and the routine that called us might had some use for it.
    mov al, [es:di]         ; Get the byte at ES:DI address in memory
    push ax                 ; Save it to the stack.
    mov al, [ds:si]         ; Get the byte at DS:SI address in memory
    push ax                 ; Save it to the stack.

    ; Now with the values saved in the stack, make one address have all zeros and the other address all ones.
    mov byte[es:di], 0x00
    mov byte[ds:si], 0xFF   ; Looping of memory might happen here!

    ; We compare the lower 2 bytes addressed by ES:DI. This _should_ be 0x00 since we set it explicitly above,
    ; but if memory is actually looping (i.e. A20 disabled) then this will hold the same value as [DS:SI], which
    ; is 0xFF.
    cmp byte[es:di], 0xFF

    ; We now have our desired information in the Zero Flag, so let's restore the values we initially had in [ES:DI] and [DS:SI].
    pop ax
    mov byte[ds:si], al     ; Remember that the last push to the stack was for [DS:SI], so restore that one first.

    pop ax
    mov byte[es:di], al     ; Restore [ES:DI] original value.

    ; We're using AX as our return register.
    mov ax, 0               ; A20 is disabled.
    je check_a20_end        ; Here we check the CMP instruction from above. If the values were the same then keep AX with 0 since A20 is disabled.

    ; Reaching this part of the routine means the jump above was not performed, so that means the values were differet.
    ; This means A20 is enabled!
    mov ax, 1               ; A20 is enabled.
check_a20_end:
    ; This is the end, restore FLAGS and registers we used.
    pop di
    pop es
    pop si
    pop ds
    popf

    ret