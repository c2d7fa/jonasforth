format ELF64 executable

struc with_length string& {
    . db string
    .length = $ - .
}

macro write_stdout string_label {
    mov rax, 1
    mov rdi, 1
    mov rsi, string_label
    mov rdx, string_label#.length
    syscall
}

segment readable executable

start:
    write_stdout message

    jmp $

segment readable

message with_length 'Hello, world!',$A
