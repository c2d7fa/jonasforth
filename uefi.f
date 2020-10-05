: ConOut SystemTable 64 + @ ;
: ConOut.OutputString ConOut 8 + @ ;
: ConOut.OutputString() ConOut SWAP ConOut.OutputString EFICALL2 ;

HERE @
  97 C, 0 C, 98 C, 0 C, 99 C, 0 C, \ "ABC\0"
ConOut.OutputString()
