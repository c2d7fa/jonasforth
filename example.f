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

HELLO
TEST-FIB
