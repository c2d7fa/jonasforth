: ConOut SystemTable 64 + @ ;
: ConOut.OutputString ConOut 8 + @ ;
: ConOut.OutputString() ConOut SWAP ConOut.OutputString EFICALL2 ;

: BootServices SystemTable 96 + @ ;
: BootServices.LocateProtocol BootServices 320 + @ ;
: GraphicsOutputProtocol
  \ [TODO] It would be nice to cache this value, so we don't have to get it
  \ every time.
  HERE @ 5348063987722529246 , 7661046075708078998 , \ *Protocol = EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID
  0 \ *Registration
  HERE @ 0 , \ **Interface
  BootServices.LocateProtocol EFICALL3 DROP
  HERE @ 8 - @ \ *Interface
  ;
: GOP.Blt GraphicsOutputProtocol 16 + @ ;
: GOP.Blt() ( GOP buffer mode sx sy dx dy dw dh pitch -- )
  GOP.Blt EFICALL10 0 = IF ELSE S" Warning: Invalid Blt()" TELL THEN ;
: GOP.SetMode GraphicsOutputProtocol 8 + @ ;

: EfiBltVideoFill 0 ;

\ Store a null-terminated UTF-16 string HERE, and return a pointer to its buffer
\ at runtime.
: UTF16"
  HERE @
  BEGIN
    KEY DUP C,
    0 C,
  34 = UNTIL
  HERE @ 2 - HERE ! \ Remove final "
  0 C, 0 C, \ Null terminator
  ;
