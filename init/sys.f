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
  AGAIN ; ( Yay! We now have comments! )

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

: C,
  HERE @ C!
  HERE @ 1 +
  HERE ! ;

: OVER ( a b -- a b a ) SWAP DUP ROT ;

( An alternative comment syntax. Reads until the end of the line. )
: \ IMMEDIATE
  BEGIN
    KEY
  10 = UNTIL ;

\ So far, S" has only worked in immediate mode, which is backwards -- actually,
\ the main use-case of this is as a compile-time word. Let's fix that.
: S" IMMEDIATE
  ' LITSTRING ,
  HERE @ 0 C, \ We will put the length here
  0
  BEGIN
    1 +
    KEY DUP C,
  34 = UNTIL
  \ Remove final "
    HERE @ 1 - HERE !
    1 -
  SWAP C! ;

( Compile the given string into the current word directly. )
: STORE-STRING ( str len -- )
  BEGIN
    OVER C@ C,
    SWAP 1 + SWAP
  1 - DUP 0 = UNTIL
  DROP DROP ;

: NEWLINE 10 EMIT ;
: SPACE 32 EMIT ;

( Read a number from standard input. )
: READ-NUMBER READ-WORD PARSE-NUMBER ;

: RESTART S" Ready." TELL NEWLINE ;
RESTART

