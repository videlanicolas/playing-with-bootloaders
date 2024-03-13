; This routine tries to enable A20 through BIOS interrupts.
; The BIOS has interrupt 15h with services:
; * 2401h: Activate A20
; * 2402h: Check A20 status (yeah I know, we made a huge custom implementation to check this when we could just call the BIOS...).
; * 2403h: Check if A20 enable/disable is supported at this interrupt routine.
enable_a20:
    pusha               ; Save the state of all registers

    ; First check if the BIOS supports this functionality.
    mov ax, 2403h           ; Service used to check support of A20 enable service.
    int 15h                 ; Call the BIOS.
    jb a20_not_supported    ; BIOS sets CF to 1 if there was an error, so terminate this routine if so. JB is Jump if below, which actually checks if CF = 1.
    cmp ah, 0               ; If BIOS supports this then AH is 0.
    jne a20_not_supported

    ; Ok, so A20 fuctionality is supported in the BIOS. Let's enable it then.
    mov ax, 2401h           ; Service used to enable A20.
    int 15h                 ; Call the BIOS.
    jb a20_fail_to_activate ; If CF is set then this operation failed.
    cmp ah, 0               ; If AH is different than 0 then the BIOS failed to enable A20.
    jne a20_fail_to_activate

    ; If we reached this point then A20 is enabled!
    jmp enable_a20_end

; Print a string saying BIOS failed to enable A20.
a20_fail_to_activate:

mov bx, A20_FAIL_TO_ACTIVATE_MSG
call print_string
xor ax, ax                          ; Set CF so we can later check for error.
jmp enable_a20_end                  ; Skip the sub-routine below and go straight to the end.

; Print a string saying this is not supported.
a20_not_supported:

mov bx, A20_NOT_SUPPORTED_MSG
call print_string
xor ax, ax                          ; Set CF so we can later check for error.

; End our routine.
enable_a20_end:
    popa            ; Restore all the registers we modified.
    ret             ; Go back to where we were called.

A20_NOT_SUPPORTED_MSG: db "A20 BIOS functionality not supported.", 0x0d, 0x0a, 0
A20_FAIL_TO_ACTIVATE_MSG: db "BIOS failed to enable A20.", 0x0d, 0x0a, 0