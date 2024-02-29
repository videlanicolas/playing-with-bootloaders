; Print a 16 bit HEX address stored at CX
; Watch out, it's including print_string.asm!
print_hex:
    pusha                       ; Save all registers to the stack.
    mov bx, PRINT_HEX_STR+2     ; Get hte first char in the hex string, after '0x'.
    mov ax, 0xf000              ; The start mask, this will slide 'f' to the right.
    mov [INPUT_VAR], cx         ; We'll reference this later, so we free CX.
    mov cx, 12                  ; Number of bits to shift right in DX, this will be a sliding unmber.

print_hex_loop:
    ; We need to manipulate the string in BX to change it 
    ; to the correspondig ASCII byte of that same number.
    mov dx, [INPUT_VAR]         ; Get a fresh copy of the word to print.
    and dx, ax                  ; Apply the mask.
    shr dx, cl                  ; Get rid of all the zeros.
    call print_hex_add_ascii    ; Convert the resulting byte to ASCII.
    
    ; Once the correct ASCII byte was calculated, copy it to where BX is pointing.
    mov [bx], dx

    ; The following is preparing all registers to the next iteration of this loop.
    inc bx                      ; Get the next address to print.
    shr ax, 4                   ; Get the next mask.
    sub cl, 4                   ; Next time we'll only need to shift 4 bits less.
    cmp ax, 0x0000              ; If this is zero then we're done.
    jne print_hex_loop

    ; Finally print the hex with the modified bits.
    mov bx, PRINT_HEX_STR       ; Get the address of the modified string.
    call print_string           ; Print it, it now contains the ASCII representation of the HEX bytes.

    ; Return gracefully by restoring the values of all registers.
    popa
    ret

; Adds 48 if this is a number, so it matches with 0-9 in ASCII.
; Adds 87 if this is a letter, so it matches with a-f in ASCII.
print_hex_add_ascii:
    cmp dx, 9                       ; if dx >= 9
    jge print_hex_add_ascii_letter  
    add dx, 48                      ; else add 48 (it's an ASCII number).
    jmp print_hex_add_ascii_end
    print_hex_add_ascii_letter:     ; dx is a letter.
    add dx, 87 

    print_hex_add_ascii_end:
    ret

%include "./src/common/print_string.asm" ; This is getting included!

; Data

PRINT_HEX_STR: db "0x0000",0
INPUT_VAR: dw 0x0000