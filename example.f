( vim: syntax=forth
)

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

S" HELLO-ADDR" CREATE
S" Hello!" DUP ROT
STORE-STRING
: HELLO
  ' HELLO-ADDR LIT, TELL NEWLINE ;

HELLO

S" 10 FIB = " TELL
10 FIB .U
SPACE S" (Expected: 59)" TELL NEWLINE

TERMINATE
