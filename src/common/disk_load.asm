; Load DH sectors from disk to ES:BX from drive in DL.
disk_load:
    push dx         ; Save DX state to the stack, we're going to use it afterwards.

    mov ah, 0x02    ; Read sector service.
    mov al, dh      ; Read DH sectors.
    mov cx, 0x0002  ; Cylinder 0 (CH) and start reading from sector 2 (CL) (sector 1 is the bootloader).
    mov dh, 0x00    ; Head 0.
    int 0x13        ; BIOS routine to read from disk.

    pop dx          ; Restore DX so we clean the stack if we error out.
    jc disk_error   ; CF (Carry flag) is set if there was an error.

    ; Even if there was no error reading the disk, we need to check if all sectors were successfully read.
    cmp dh, al      ; If DH and AL differ, then some sectors failed to read.
    jne disk_error

    ret

disk_error:
    mov bx, DISK_ERROR_MSG
    call print_string
    shr ax, 8               ; Error code is in AH, we need to move it to the least significant bits.
    mov cx, ax
    call print_hex          ; Print the error code.
    shl ax, 8               ; Restore AH where it belongs.
    
    ret

%include "./src/common/print_hex.asm"

; Data
DISK_ERROR_MSG: db "Disk read error!", 0x0d, 0x0a, "Error code: ", 0