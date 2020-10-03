;; vim: syntax=fasm

format pe64 dll efi
entry main

;; EFI struct definitions {{{

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

;; }}}

section '.text' code executable readable

os_initialize:
  ; At program startup, RDX contains an EFI_SYSTEM_TABLE*.
  mov [system_table], rdx
  ret

os_print_string:
  ;; We take an input string of bytes without any terminator. We need to turn
  ;; this string into a string of words, terminated by a null character.

  mov rdi, .output_buffer ; Current location in output string

.copy_byte:
  ;; When there are no characters left in the input string, we are done.
  cmp rdx, 0
  je .done

  ;; Load byte from input string
  mov al, byte [rcx]

  ;; Copy byte to output string

  cmp al, $A
  jne .not_newline
.newline:
  ;; It's a newline; replace it with '\r\n' in output string.
  mov byte [rdi], $D
  inc rdi
  mov byte [rdi], 0
  inc rdi
  mov byte [rdi], $A
  inc rdi
  mov byte [rdi], 0
  inc rdi
  jmp .pop

.not_newline:
  ;; Not a newline, proceed as normal:
  mov byte [rdi], al
  inc rdi

  ;; The output string has words rather than bytes for charactesr, so we need
  ;; to add an extra zero:
  mov byte [rdi], 0
  inc rdi

.pop:
  ;; We finished copying character to output string, so pop it from the input
  ;; string.
  inc rcx
  dec rdx

  jmp .copy_byte
.done:
  ;; Append a final null-word:
  mov word [rdi], 0

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

os_read_char:
  mov r15, rcx
.read_key:
  mov rcx, [system_table]                                       ; EFI_SYSTEM_TABLE* rcx
  mov rcx, [rcx + EFI_SYSTEM_TABLE.ConIn]                       ; EFI_SIMPLE_TEXT_INPUT_PROTOCOL* rcx
  mov rbx, [rcx + EFI_SIMPLE_TEXT_INPUT_PROTOCOL.ReadKeyStroke] ; EFI_INPUT_READ_KEY rbx
  mov rdx, input_key                                            ; EFI_INPUT_KEY* rdx
  sub rsp, 32
  call rbx
  add rsp, 32

  mov r8, EFI_NOT_READY
  cmp rax, r8
  je .read_key

  mov ax, [input_key.UnicodeChar]
  mov [r15], al

  ;; Special handling of enter (UEFI gives us '\r', but we want '\n'.)
  cmp ax, $D
  jne .no_enter
  mov byte [r15], $A
.no_enter:

  ;; Print the character
  mov rcx, r15
  mov rdx, 1
  call os_print_string

  ret

;; Terminate with the given error code.
;;
;; Inputs:
;; - RCX = Error code
os_terminate:
  mov rcx, terminated_msg
  mov rdx, terminated_msg.len
  call os_print_string
  jmp $

section '.data' readable writable

system_table dq ? ; EFI_SYSTEM_TABLE*

terminated_msg db 0xD, 0xA, '(The program has terminated.)', 0xD, 0xA
.len = $ - terminated_msg

os_print_string.output_buffer rq 0x400

char_buffer db ?

input_key EFI_INPUT_KEY
