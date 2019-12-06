format ELF64 executable

;; The code in this macro is placed at the end of each Forth word. When we are
;; executing a definition, this code is what causes execution to resume at the
;; next word in that definition.
macro next {
  ;; RSI points to the address of the definition of the next word to execute.
  lodsq                   ; Load value at RSI into RAX and increment RSI
  ;; Now RAX contains the location of the next word to execute. The first 8
  ;; bytes of this word is the address of the codeword, which is what we want
  ;; to execute.
  jmp qword [rax]         ; Jump to the codeword of the current word
}

;; pushr and popr work on the return stack, whose location is stored in the
;; register RBP.
macro pushr x {
  sub rbp, 8
  mov qword [rbp], x
}
macro popr x {
  mov x, [rbp]
  add rbp, 8
}

;; The following macro generates the dictionary header. It updates the
;; initial_latest_entry variable, which is used as the initial value of the
;; latest_entry variable that is made available at runtime.
;;
;; The header contains a link to the previous entry, the length of the name of
;; the word and the word itself as a string literal.
;;
;; This macro also defines a label LABEL_entry.
initial_latest_entry = 0
macro header label, name {
  local .string_end

label#_entry:
  dq initial_latest_entry
  db .string_end - ($ + 1)
  db name
  .string_end:
label:

initial_latest_entry = label#_entry
}

;; Define a Forth word that is implemented in assembly. See 'header' for details.
macro forth_asm label, name {
  header label, name
  dq .start
.start:
}

;; Define a Forth word that is implemented in Forth. (The body will be a list of
;; 'dq' statements.)
macro forth label, name {
  header label, name
  dq DOCOL
}

segment readable executable

entry main

include "impl.asm"

main:
  cld                        ; Clear direction flag so LODSQ does the right thing.
  mov rbp, return_stack_top  ; Initialize return stack

  mov rax, MAIN
  jmp qword [rax]

program: dq MAIN

;; The codeword is the code that will be executed at the beginning of a forth
;; word. It needs to save the old RSI and update it to point to the next word to
;; execute.
header DOCOL, 'DOCOL'
  pushr rsi            ; Save old value of RSI on return stack; we will continue execution there after we are done executing this word
  lea rsi, [rax + 8]   ; RAX currently points to the address of the codeword, so we want to continue at RAX+8
  next                 ; Execute word pointed to by RSI

;; This word is called at the end of a Forth definition. It just needs to
;; restore the old value of RSI (saved by 'DOCOL') and resume execution.
forth_asm EXIT, 'EXIT'
  popr rsi
  next

;; LIT is a special word that reads the next "word pointer" and causes it to be
;; placed on the stack rather than executed.
forth_asm LIT, 'LIT'
  lodsq
  push rax
  next

;; Given a string (a pointer following by a size), return the location of the
;; dictionary entry for that word. If no such word exists, return 0.
forth_asm FIND, 'FIND'
  mov [.rsi], rsi

  pop [find.search_length]
  pop [find.search_buffer]
  mov rsi, [latest_entry]       ; Start with the last added word
  call find
  push rsi

  mov rsi, [.rsi]
  next
  push rsi

  mov rsi, [.rsi]
  next

;; Given an entry in the dictionary, return a pointer to the codeword of that
;; entry.
forth_asm TCFA, '>CFA'
  pop rax
  add rax, 8                    ; [rax] = length of name
  movzx rbx, byte [rax]
  inc rax
  add rax, rbx                  ; [rax] = codeword
  push rax
  next

;; BRANCH is the fundamental mechanism for branching. BRANCH reads the next word
;; as a signed integer literal and jumps by that offset.
forth_asm BRANCH, 'BRANCH'
  add rsi, [rsi] ; [RSI], which is the next word, contains the offset; we add this to the instruction pointer.
  next           ; Then, we can just continue execution as normal

;; 0BRANCH is like BRANCH, but it jumps only if the top of the stack is zero.
forth_asm ZBRANCH, '0BRANCH'
  ;; Compare top of stack to see if we should branch
  pop rax
  cmp rax, 0
  jnz .dont_branch
.do_branch:
  jmp BRANCH.start
.dont_branch:
  add rsi, 8     ; We need to skip over the next word, which contains the offset.
  next

;; Duplicate the top of the stack.
forth_asm DUP_, 'DUP'
  push qword [rsp]
  next

;; Execute the codeword at the given address.
forth_asm EXEC, 'EXEC'
  pop rax
  jmp qword [rax]

;; Expects a character on the stack and prints it to standard output.
forth_asm EMIT, 'EMIT'
  pushr rsi
  pushr rax
  mov rax, 1
  mov rdi, 1
  lea rsi, [rsp]
  mov rdx, 1
  syscall
  add rsp, 8
  popr rax
  popr rsi
  next

;; Prints a newline to standard output.
forth NEWLINE, 'NEWLINE'
  dq LIT, $A
  dq EMIT
  dq EXIT

;; Prints a space to standard output.
forth SPACE, 'SPACE'
  dq LIT, ' '
  dq EMIT
  dq EXIT

;; Read a word from standard input and push it onto the stack as a pointer and a
;; size. The pointer is valid until the next call to READ_WORD.
forth_asm READ_WORD, 'READ-WORD'
  mov [.rsi], rsi

  call read_word
  push rdi                      ; Buffer
  push rdx                      ; Length

  mov rsi, [.rsi]
  next

;; Takes a string on the stack and replaces it with the decimal number that the
;; string represents.
forth_asm PARSE_NUMBER, 'PARSE-NUMBER'
  pop [parse_number.length]     ; Length
  pop [parse_number.buffer]     ; String pointer

  push rsi
  call parse_number
  pop rsi

  push rax                      ; Result
  next

forth READ_NUMBER, 'READ-NUMBER'
  dq READ_WORD
  dq PARSE_NUMBER
  dq EXIT

;; Takes a string (in the form of a pointer and a length on the stack) and
;; prints it to standard output.
forth_asm TELL, 'TELL'
  mov rbx, rsi
  mov rcx, rax

  mov rax, 1
  mov rdi, 1
  pop rdx     ; Length
  pop rsi     ; Buffer
  syscall

  mov rax, rcx
  mov rsi, rbx
  next

;; Exit the program cleanly.
forth_asm TERMINATE, 'TERMINATE'
  mov rax, $3C
  mov rdi, 0
  syscall

forth HELLO, 'HELLO'
  dq LIT, 'H', EMIT
  dq LIT, 'e', EMIT
  dq LIT, 'l', EMIT
  dq LIT, 'l', EMIT
  dq LIT, 'o', EMIT
  dq LIT, '!', EMIT
  dq NEWLINE
  dq EXIT

;; Duplicate a pair of elements.
forth_asm PAIRDUP, '2DUP'
  pop rbx
  pop rax
  push rax
  push rbx
  push rax
  push rbx
  next

;; Swap the top two elements on the stack.
forth_asm SWAP, 'SWAP'
  pop rax
  pop rbx
  push rax
  push rbx
  next

;; Remove the top element from the stack.
forth_asm DROP, 'DROP'
  add rsp, 8
  next

;; The INTERPRET word reads and interprets user input. It's behavior depends on
;; the current STATE. It provides special handling for integers. (TODO)
forth INTERPRET, 'INTERPRET'
  ;; Read word
  dq READ_WORD
  dq PAIRDUP
  ;; Stack is (word length word length).
  dq FIND                       ; Try to find word
  dq DUP_
  dq ZBRANCH, 8 * 8             ; Check if word is found

  ;; Word is found, execute it
  dq TCFA
  ;; Stack is (word length addr)
  dq SWAP, DROP
  dq SWAP, DROP
  ;; Stack is (addr)
  dq EXEC
  dq EXIT

  ;; No word is found, assume it is an integer literal
  ;; Stack is (word length addr)
  dq DROP
  dq PARSE_NUMBER
  dq EXIT

;; .U prints the value on the stack as an unsigned integer in hexadecimal.
forth_asm DOTU, '.U'
  mov [.length], 0
  mov [.printed_length], 1
  pop rax                       ; RAX = value to print
  push rsi                      ; Save value of RSI

  ;; We start by constructing the buffer to print in reverse

.loop:
  mov rdx, 0
  mov rbx, $10
  div rbx                       ; Put remainer in RDX and quotient in RAX

  ;; Place the appropriate character in the buffer
  mov rsi, .chars
  add rsi, rdx
  mov bl, [rsi]
  mov rdi, .rbuffer
  add rdi, [.length]
  mov [rdi], bl
  inc [.length]

  ;; .printed_length is the number of characters that we ulitmately want to
  ;; print. If we have printed a non-zero character, then we should update
  ;; .printed_length.
  cmp bl, '0'
  je .skip_updating_real_length
  mov rbx, [.length]
  mov [.printed_length], rbx
.skip_updating_real_length:

  cmp [.length], 16
  jle .loop

  ;; Flip buffer around, since it is currently reversed
  mov rcx, [.printed_length]
.flip:
  mov rsi, .rbuffer
  add rsi, rcx
  dec rsi
  mov al, [rsi]

  mov rdi, .buffer
  add rdi, [.printed_length]
  sub rdi, rcx
  mov [rdi], al

  loop .flip

  ;; Print the buffer
  mov rax, 1
  mov rdi, 1
  mov rsi, .buffer
  mov rdx, [.printed_length]
  syscall

  ;; Restore RSI and continue execution
  pop rsi
  next

;; Takes a value and an address, and stores the value at the given address.
forth_asm PUT, '!'
  pop rbx                       ; Address
  pop rax                       ; Value
  mov [rbx], rax
  next

;; Takes an address and returns the value at the given address.
forth_asm GET, '@'
  pop rax
  mov rax, [rax]
  push rax
  next

;; Add two integers on the stack.
forth_asm PLUS, '+'
  pop rax
  pop rbx
  add rax, rbx
  push rax
  next

;; Calculate difference between two integers on the stack. The second number is
;; subtracted from the first.
forth_asm MINUS, '-'
  pop rax
  pop rbx
  sub rbx, rax
  push rbx
  next

;; Get the location of the STATE variable. It can be set with '!' and read with
;; '@'.
forth STATE, 'STATE'
  dq LIT, var_STATE
  dq EXIT

;; Get the location of the LATEST variable. It can be set with '!' and read with
;; '@'.
forth LATEST, 'LATEST'
  dq LIT, latest_entry
  dq EXIT

;; Get the location at which compiled words are expected to be added. This
;; pointer is usually modified automatically when calling ',', but we can also
;; read it manually with 'HERE'.
forth HERE, 'HERE'
  dq LIT, here
  dq EXIT

forth COMMA, ','
  dq HERE, GET, PUT             ; Set the memory at the address pointed to by HERE
  dq HERE, GET, LIT, 8, PLUS    ; Calculate new address for HERE to point to
  dq HERE, PUT                  ; Update HERE to point to the new address
  dq EXIT

;; Read user input until next " character is found. Push a string containing the
;; input on the stack as (buffer length). Note that the buffer is only valid
;; until the next call to S" and that no more than 255 character can be read.
forth_asm READ_STRING, 'S"'
  push rsi

  mov [.length], 0

.read_char:
  mov rax, 0
  mov rdi, 0
  mov rsi, .char_buffer
  mov rdx, 1
  syscall

  mov al, [.char_buffer]
  cmp al, '"'
  je .done

  mov rdx, .buffer
  add rdx, [.length]
  mov [rdx], al
  inc [.length]
  jmp .read_char

.done:
  pop rsi

  push .buffer
  push [.length]

  next

;; CREATE inserts a new header in the dictionary, and updates LATEST so that it
;; points to the header. To compile a word, the user can then call ',' to
;; continue to append data after the header.
;;
;; It takes the name of the word as a string (address length) on the stack.
forth_asm CREATE, 'CREATE'
  pop rcx                       ; Word string length
  pop rdx                       ; Word string pointer

  mov rdi, [here]               ; rdi = Address at which to insert this entry
  mov rax, [latest_entry]       ; rax = Address of the previous entry
  mov [rdi], rax                ; Insert link to previous entry
  mov [latest_entry], rdi       ; Update LATEST to point to this word

  add rdi, 8
  mov [rdi], rcx                ; Insert length

  ;; Insert word string
  add rdi, 1

  push rsi
  mov rsi, rdx                  ; rsi = Word string pointer
  rep movsb
  pop rsi

  ;; Update HERE
  mov [here], rdi

  next

forth MAIN, 'MAIN'
  dq HELLO
  dq INTERPRET
  dq BRANCH, -8 * 2
  dq TERMINATE

segment readable writable

;; The LATEST variable holds a pointer to the word that was last added to the
;; dictionary. This pointer is updated as new words are added, and its value is
;; used by FIND to look up words.
latest_entry dq initial_latest_entry

;; The STATE variable is 0 when the interpreter is executing, and non-zero when
;; it is compiling.
var_STATE dq 0

FIND.rsi dq ?

READ_WORD.rsi dq ?
READ_WORD.rbp dq ?

READ_STRING.char_buffer db ?
READ_STRING.buffer rb $FF
READ_STRING.length dq ?

DOTU.chars db '0123456789ABCDEF'
DOTU.buffer rq 16               ; 64-bit number has no more than 16 digits in hex
DOTU.rbuffer rq 16
DOTU.length dq ?
DOTU.printed_length dq ?

;; Reserve space for compiled words, accessed through HERE.
here dq here_top
here_top rq $2000

;; Return stack
rq $2000
return_stack_top:
