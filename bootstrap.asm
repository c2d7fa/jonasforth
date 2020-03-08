;; vim: syntax=fasm

;; We need some basic words to be available before we can implement the actual
;; interpreter. For this reason we need to write some words in assembly, even
;; though they depend only on other Forth words. Such words are defined in this
;; file.
;;
;; With these words, we can finally defined INTERPRET, and from there we'll load
;; everything else from an external file.
;;
;; This file is included from main.asm; see that file for more information.

;; Define a Forth word that is implemented in Forth. (The body will be a list of
;; 'dq' statements.)
macro forth label, name, immediate {
  header label, name, immediate
  dq DOCOL
}

forth COMMA, ','
  dq HERE, GET, PUT             ; Set the memory at the address pointed to by HERE
  dq HERE, GET, LIT, 8, PLUS    ; Calculate new address for HERE to point to
  dq HERE, PUT                  ; Update HERE to point to the new address
  dq EXIT

;; Mark the last added word as immediate.
forth IMMEDIATE, 'IMMEDIATE', 1
  dq LIT, 1
  dq LATEST, GET
  dq LIT, 8, PLUS
  dq PUT_BYTE
  dq EXIT

;; Given the address of a word, return 0 if the given word is not immediate.
forth IS_IMMEDIATE, 'IMMEDIATE?'
  dq LIT, 8, PLUS
  dq GET_BYTE
  dq EXIT

;; Enter immediate mode, immediately
forth INTO_IMMEDIATE, '[', 1
  dq LIT, 0, STATE, PUT_BYTE
  dq EXIT

;; Enter compilation mode
forth OUTOF_IMMEDIATE, ']'
  dq LIT, 1, STATE, PUT_BYTE
  dq EXIT

;; INTERPRET-WORD expects a word as a (buffer, length) pair on the stack. It
;; interprets and executes the word. It's behavior depends on the current STATE.
;; It provides special handling for integers.
forth INTERPRET_WORD, 'INTERPRET-WORD'
  dq PAIRDUP
  ;; Stack is (word length word length).
  dq FIND                       ; Try to find word
  dq DUP_
  dq ZBRANCH, 8 * 22            ; Check if word is found

  ;; - Word is found -

  dq STATE, GET, ZBRANCH, 8 * 11 ; Check whether we are in compilation or immediate mode

  ;; (Word found, compilation mode)
  dq DUP_, IS_IMMEDIATE, NOT_, ZBRANCH, 8 * 6 ; If the word is immediate, continue as we would in immediate mode

  ;; Otherwise, we want to compile this word
  dq TCFA
  dq COMMA
  dq DROP, DROP
  dq EXIT

  ;; (Word found, immediate mode)
  ;; Execute word
  dq TCFA
  ;; Stack is (word length addr)
  dq SWAP, DROP
  dq SWAP, DROP
  ;; Stack is (addr)
  dq EXEC
  dq EXIT

  ;; - No word is found, assume it is an integer literal -
  ;; Stack is (word length addr)
  dq DROP
  dq PARSE_NUMBER

  dq STATE, GET, ZBRANCH, 8 * 5 ; Check whether we are in compilation or immediate mode

  ;; (Number, compilation mode)
  dq LIT, LIT, COMMA
  dq COMMA
  dq EXIT

  ;; (Number, immediate mode)
  dq EXIT

;; The INTERPRET word reads and interprets a single word from the user.
forth INTERPRET, 'INTERPRET'
  dq READ_WORD
  dq INTERPRET_WORD
  dq EXIT

;; INTERPRET_STRING is a variant of INTERPRET that reads from a string instead
;; of from the user. It takes a string as a (buffer, length) pair on the stack
;; and interprets the entire string, even if the string has more than one word.
forth INTERPRET_STRING, 'INTERPRET-STRING'
  dq INPUT_LENGTH, PUT
  dq INPUT_BUFFER, PUT

  ;; Check if the buffer is-non-empty
  ;; [TODO] This probably won't work for strings with whitespace at the end.
  dq INPUT_LENGTH, GET
  dq ZBRANCH, 8 * 19 ; to EXIT

  dq INPUT_BUFFER, GET
  dq INPUT_LENGTH, GET
  dq POP_WORD

  ;; Stack is (buffer buffer-length word word-length)

  dq ROT, ROT
  dq INPUT_LENGTH, PUT
  dq ROT, ROT
  dq INPUT_BUFFER, PUT

  dq INTERPRET_WORD
  dq BRANCH, -8 * 19 ; to INPUT-LENGTH @

  dq EXIT
