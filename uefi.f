: ConOut SystemTable 64 + @ ;
: ConOut.OutputString ConOut 8 + @ ;
: ConOut.OutputString() ConOut SWAP ConOut.OutputString EFICALL2 ;

: BootServices SystemTable 96 + @ ;
: BootServices.LocateProtocol BootServices 320 + @ ;
: BootServices.LocateProtocol(GOP)
  HERE @ 5348063987722529246 , 7661046075708078998 , \ *Protocol = EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID
  0 \ *Registration
  HERE @ 0 , \ **Interface
  BootServices.LocateProtocol EFICALL3 DROP
  HERE @ 8 - @ \ *Interface
  ;
: GOP.Blt BootServices.LocateProtocol(GOP) 16 + @ ;
: GOP.SetMode BootServices.LocateProtocol(GOP) 8 + @ ;

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

  BootServices.LocateProtocol(GOP) \ *This
  HERE @ 255 C, 0 C, 0 C, 0 C, \ *BltBuffer = single blue pixel
  0 \ BltOperation = EfiBltVideoFill
  0 \ SourceX
  0 \ SourceY
  100 \ DestinationX
  200 \ DestinationY
  400 \ Width
  20 \ Height
  0 \ Delta (unused)
GOP.Blt EFICALL10
.U NEWLINE
