; Print a string of chars from the address at BX until 0x00 is found.
print_string:
    pusha               ; Push all registers to the stack, so we save their state.
    mov ah, 0x0e        ; BIOS teletype routine.

    print_string_loop:

    cmp byte[bx], 0x00      ; Compare the low byte referenced by BX to the NULL byte.
    je print_string_end     ; If we found the NULL byte, end the loop.
    mov al, byte[bx]        ; Copy the byte at BX to AL, this will be printed out by the BIOS.
    int 0x10                ; https://en.wikipedia.org/wiki/INT_10H
    add bx, 1               ; Get the next 16 bit address from memory, i.e. the next char to print.
    jmp print_string_loop   ; Loop back and repeat.

    print_string_end:       ; End of the loop.

    popa                ; Restore all registers from the stack.
    ret                 ; Jump to where we were called.