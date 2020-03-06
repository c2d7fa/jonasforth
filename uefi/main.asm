format pe64 dll efi
entry main

;; #region Structs

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

;; #endregion

section '.text' code executable readable

main:
  ; At program startup, RDX contains an EFI_SYSTEM_TABLE*.
  mov [system_table], rdx

  mov rcx, [system_table] ; EFI_SYSTEM_TABLE* rcx
  mov rcx, [rcx + EFI_SYSTEM_TABLE.ConOut] ; EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL* rcx
  mov rdx, hello_world_string
  ; EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL.OutputString(EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL* rcx, CHAR16* rdx)
  mov rbx, [rcx + EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL.OutputString] ; EFI_TEXT_STIRNG rbx
  sub rsp, 32
  call rbx
  add rsp, 32

  mov rax, 0
  ret

section '.data' readable writable

system_table dq ?  ; EFI_SYSTEM_TABLE*

hello_world_string du 'Hello world!', 0xC, 0xA, 0
