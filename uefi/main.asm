;; vim: syntax=fasm

format pe64 dll efi
entry main

;; [TODO] We need to provide the following:
;; - [X] Print a string of a given length
;; - [ ] Print a single character
;; - [ ] Terminate the program (? - What should this do?)
;; - [X] Read a single character
;;       - This should allow the user to type in a string, and then feed the
;;         buffer to us one character at a time.
;;       - [ ] We want to show the user's input on the screen while reading

;; #region Structs

EFI_NOT_READY = 0x8000_0000_0000_0000 or 6

;; Based on https://wiki.osdev.org/Uefi.inc
macro struct name {
  virtual at 0
    name name
  end virtual
}

struc EFI_TABLE_HEADER {
  dq ?
  dd ?
  dd ?
  dd ?
  dd ?
}

struc EFI_SYSTEM_TABLE {
  .Hdr EFI_TABLE_HEADER
  .FirmwareVendor dq ? ; CHAR16*
  .FirmwareRevision dd ? ; UINT32
  align 8
  .ConsoleInHandle dq ? ; EFI_HANDLE
  .ConIn dq ? ; EFI_SIMPLE_TEXT_INPUT_PROTOCOL*
  .ConsoleOutHandle dq ? ; EFI_HANDLE
  .ConOut dq ? ; EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL*
  ; ...
}
struct EFI_SYSTEM_TABLE

struc EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL {
  .Reset dq ? ; EFI_TEXT_RESET
  .OutputString dq ? ; EFI_TEXT_STRING
  ; ...
}
struct EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL

struc EFI_SIMPLE_TEXT_INPUT_PROTOCOL {
  .Reset dq ? ; EFI_INPUT_RESET
  .ReadKeyStroke dq ? ; EFI_INPUT_READ_KEY
  ; ...
}
struct EFI_SIMPLE_TEXT_INPUT_PROTOCOL

struc EFI_INPUT_KEY {
  .ScanCode dw ? ; UINT16
  .UnicodeChar dw ? ; CHAR16
  align 8
}
struct EFI_INPUT_KEY

;; #endregion

section '.text' code executable readable

main:
  ; At program startup, RDX contains an EFI_SYSTEM_TABLE*.
  mov [system_table], rdx

  mov rcx, hello_string
  mov rdx, hello_string.len
  call print_string

  mov rcx, char_buffer
  call read_char

  mov rcx, char_buffer
  mov rdx, 1
  call print_string

  mov rcx, hello_string
  mov rdx, hello_string.len
  call print_string

  ret

;; Print a string of the given length.
;;
;; Inputs:
;;  - RCX = String buffer
;;  - RDX = String length
print_string:
  mov r8, rcx
  mov r9, rdx

  mov r10, r9
  add r10, r10

  ; We take an input string of bytes without any terminator. We need to turn
  ; this string into a string of words, terminated by a null character.
  mov rcx, 0
  mov rsi, 0
.copy_byte:
  cmp rcx, r10
  je .done

  mov al, byte [r8 + rsi]
  lea rdx, [.output_buffer + rcx]
  mov byte [rdx], al
  inc rcx
  inc rsi

  lea rdx, [.output_buffer + rcx]
  mov byte [rdx], 0
  inc rcx

  jmp .copy_byte
.done:
  lea rdx, [.output_buffer + r10]
  mov byte [rdx], 0

  ; At this point we have our null-terminated word-string at .output_buffer. Now
  ; we just need to print it.

  mov rcx, [system_table]                                       ; EFI_SYSTEM_TABLE* rcx
  mov rcx, [rcx + EFI_SYSTEM_TABLE.ConOut]                      ; EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL* rcx
  mov rdx, .output_buffer
  mov rbx, [rcx + EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL.OutputString] ; EFI_TEXT_STRING rbx
  sub rsp, 32
  call rbx
  add rsp, 32
  ret

;; Read a character as an ASCII byte into the given buffer.
;;
;; Inputs:
;; - RCX = Character buffer (1 byte)
read_char:
  mov r15, rcx
.read_key:
  mov rcx, [system_table] ; EFI_SYSTEM_TABLE* rcx
  mov rcx, [rcx + EFI_SYSTEM_TABLE.ConIn] ; EFI_SIMPLE_TEXT_INPUT_PROTOCOL* rcx
  mov rbx, [rcx + EFI_SIMPLE_TEXT_INPUT_PROTOCOL.ReadKeyStroke] ; EFI_INPUT_READ_KEY rbx
  mov rdx, input_key ; EFI_INPUT_KEY* rdx
  sub rsp, 32
  call rbx
  add rsp, 32

  mov r8, EFI_NOT_READY
  cmp rax, r8
  je .read_key

  mov ax, [input_key.UnicodeChar]
  mov [r15], al

  ret

section '.data' readable writable

system_table dq ?  ; EFI_SYSTEM_TABLE*

hello_string db 'Hello, world!', 0xD, 0xA, 'Here is some more text.', 0xD, 0xA
.len = $ - hello_string

print_string.output_buffer rq 0x400

char_buffer db ?

input_key EFI_INPUT_KEY
