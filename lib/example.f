: FIB ( n -- Fn )
  0 1                            ( n a b )
  0                              ( n a b i )
  BEGIN
    ROT                          ( n i a b )
    DUP ROT +                    ( n i b a+b )
    ROT ROT                      ( n b a+b i )

    1 +                          ( n b a+b i+1 )
  DUP 4 PICK = UNTIL
  DROP SWAP DROP SWAP DROP ;     ( a+b )

: HELLO S" Hello!" TELL NEWLINE ;

: TEST-FIB
  S" 10 FIB = " TELL
  10 FIB .U
  SPACE S" (Expected: 59)" TELL NEWLINE ;

\ This example calls the Blt() function on UEFI's Graphics Output Protocol. See
\ the UEFI specification and uefi.f for more information.
: BLUE-SQUARE
  GraphicsOutputProtocol
  HERE @ 255 C, 0 C, 0 C, 0 C, \ Buffer with single blue pixel
  EfiBltVideoFill
  0 0 \ Source
  100 100 20 20 \ Destination
  0
  GOP.Blt() ;

HELLO
TEST-FIB
BLUE-SQUARE
