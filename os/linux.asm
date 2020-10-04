format ELF64 executable
entry main

macro os_code_section {
  segment readable executable
}

macro os_data_section {
  segment readable writable
}

os_code_section

os_initialize:
  ret

os_print_string:
  push rsi
  mov rax, 1
  mov rdi, 1
  mov rsi, rcx
  syscall
  pop rsi
  ret

os_read_char:
  push rsi
  mov rax, 0
  mov rdi, 0
  mov rsi, .buffer
  mov rdx, 1
  syscall
  pop rsi
  movzx rax, byte [.buffer]
  ret

os_terminate:
  mov rdi, rax
  mov rax, $3C
  syscall

os_data_section

os_read_char.buffer db ?

