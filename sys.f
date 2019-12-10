S" :" CREATE ] DOCOL
  READ-WORD CREATE
  LIT DOCOL ,
  ]
EXIT [

: ;
  LIT EXIT ,
  [ S" [" FIND >CFA , ]
  EXIT
[ IMMEDIATE

: IF IMMEDIATE
  ' 0BRANCH ,
  HERE @
  0 ,
;

: THEN IMMEDIATE
  DUP
  HERE @ SWAP -
  SWAP !
;

: ELSE IMMEDIATE
  ' BRANCH ,
  HERE @
  0 ,
  SWAP DUP HERE @ SWAP - SWAP !
;

: BEGIN IMMEDIATE
  HERE @
;

: AGAIN IMMEDIATE
  ' BRANCH ,
  HERE @ - , ;

: ( IMMEDIATE
  BEGIN
    READ-WORD
    1 = IF
      C@ 41 = IF
        EXIT
      THEN
    ELSE
      DROP
    THEN
  AGAIN ;

: UNTIL IMMEDIATE
  ' 0BRANCH ,
  HERE @ - ,
;

( Compile a literal value into the current word. )
: LIT, IMMEDIATE ( x -- )
  ' LIT , , ;

: / /MOD DROP ;
: MOD /MOD SWAP DROP ;
: NEG 0 SWAP - ;

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

: C,
  HERE @ C!
  HERE @ 1 +
  HERE ! ;

: OVER ( a b -- a b a ) SWAP DUP ROT ;

( Compile the given string into the current word directly. )
: STORE-STRING ( str len -- )
  BEGIN
    OVER C@ C,
    SWAP 1 + SWAP
  1 - DUP 0 = UNTIL
  DROP DROP ;

S" HELLO-ADDR" CREATE
S" Hello!" DUP ROT
STORE-STRING
: HELLO
  ' HELLO-ADDR LIT, TELL NEWLINE ;

HELLO

S" 10 FIB = " TELL
10 FIB .U
S"  (Expected: 59)" TELL NEWLINE

TERMINATE
