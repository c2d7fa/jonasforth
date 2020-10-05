: ConOut SystemTable 64 + @ ;
: ConOut.OutputString ConOut 8 + @ ;
: ConOut.OutputString() ConOut SWAP ConOut.OutputString EFICALL2 ;

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

UTF16" Hello UEFI!" ConOut.OutputString()
