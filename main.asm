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

segment readable executable

main:
  cld                        ; Clear direction flag so LODSQ does the right thing.
  mov rbp, return_stack_top  ; Initialize return stack

  mov rsi, program
  next

program: dq MAIN

;; The codeword is the code that will be executed at the beginning of a forth
;; word. It needs to save the old RSI and update it to point to the next word to
;; execute.
docol:
  pushr rsi            ; Save old value of RSI on return stack; we will continue execution there after we are done executing this word
  lea rsi, [rax + 8]   ; RAX currently points to the address of the codeword, so we want to continue at RAX+8
  next                 ; Execute word pointed to by RSI

;; This word is called at the end of a Forth definition. It just needs to
;; restore the old value of RSI (saved by 'docol') and resume execution.
EXIT_entry:
  dq 0
  db 4
  db 'EXIT'
EXIT:
  dq .start
.start:
  popr rsi
  next

;; LIT is a special word that reads the next "word pointer" and causes it to be
;; placed on the stack rather than executed.
LIT_entry:
  dq EXIT_entry
  db 3
  db 'LIT'
LIT:
  dq .start
.start:
  lodsq
  push rax
  next

;; Given a string (a pointer following by a size), return the location of the
;; dictionary entry for that word. If no such word exists, return 0.
FIND_entry:
  dq LIT_entry
  db 4
  db 'FIND'
FIND:
  dq .start
.start:
  mov [.rsi], rsi
  pop [.search_length]
  pop [.search_buffer]

  ;; RSI contains the entry we are currently looking at
  mov rsi, [latest_entry]       ; Start with the last added word

.loop:
  movzx rcx, byte [rsi + 8]     ; Length of word being looked at
  cmp rcx, [.search_length]
  jne .next    ; If the words don't have the same length, we have the wrong word

  ;; Otherwise, we need to compare strings
  lea rdx, [rsi + 8 + 1]        ; Location of character being compared in entry
  mov rdi, [.search_buffer]     ; Location of character being compared in search buffer
.compare_char:
  mov al, [rdx]
  mov ah, [rdi]
  cmp al, ah
  jne .next                     ; They don't match; try again
  inc rdx                       ; These characters match; look at the next ones
  inc rdi
  loop .compare_char

  jmp .found                    ; They match! We are done.

.next:
  mov rsi, [rsi]                ; Look at the previous entry
  cmp rsi, 0
  jnz .loop                    ; If there is no previous word, exit and return 0

.found:
  push rsi

  mov rsi, [.rsi]
  next

;; BRANCH is the fundamental mechanism for branching. BRANCH reads the next word
;; as a signed integer literal and jumps by that offset.
BRANCH_entry:
  dq FIND_entry
  db 6
  db 'BRANCH'
BRANCH:
  dq .start
.start:
  add rsi, [rsi] ; [RSI], which is the next word, contains the offset; we add this to the instruction pointer.
  next           ; Then, we can just continue execution as normal

;; 0BRANCH is like BRANCH, but it jumps only if the top of the stack is zero.
ZBRANCH:
  dq .start
.start:
  ;; Compare top of stack to see if we should branch
  pop rax
  cmp rax, 0
  jnz .dont_branch
.do_branch:
  jmp BRANCH.start
.dont_branch:
  add rsi, 8     ; We need to skip over the next word, which contains the offset.
  next

;; Expects a character on the stack and prints it to standard output.
EMIT:
  dq .start
.start:
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
NEWLINE:
  dq docol
  dq LIT, $A
  dq EMIT
  dq EXIT

;; Prints a space to standard output.
SPACE_entry:
  dq BRANCH_entry
  db 5
  db 'SPACE'
SPACE:
  dq docol
  dq LIT, ' '
  dq EMIT
  dq EXIT

;; Read a word from standard input and push it onto the stack as a pointer and a
;; size. The pointer is valid until the next call to READ_WORD.
READ_WORD:
  dq .start
.start:
  mov [.rsi], rsi
  mov [.rax], rax

.skip_whitespace:
  ;; Read characters into .char_buffer until one of them is not whitespace.
  mov rax, 0
  mov rdi, 0
  mov rsi, .char_buffer
  mov rdx, 1
  syscall

  cmp [.char_buffer], ' '
  je .skip_whitespace
  cmp [.char_buffer], $A
  je .skip_whitespace

.alpha:
  ;; We got a character that wasn't whitespace. Now read the actual word.
  mov [.length], 0

.read_alpha:
  mov al, [.char_buffer]
  movzx rbx, [.length]
  mov rsi, .buffer
  add rsi, rbx
  mov [rsi], al
  inc [.length]

  mov rax, 0
  mov rdi, 0
  mov rsi, .char_buffer
  mov rdx, 1
  syscall

  cmp [.char_buffer], ' '
  je .end
  cmp [.char_buffer], $A
  jne .read_alpha

.end:
  push .buffer
  movzx rax, [.length]
  push rax

  mov rsi, [.rsi]
  mov rax, [.rax]

  next

;; Takes a string on the stack and replaces it with the decimal number that the
;; string represents.
PARSE_NUMBER:
  dq .start
.start:
  pop [.length]                 ; Length
  pop rdi                       ; String pointer
  mov r8, 0                     ; Result

  ;; Add (10^(rcx-1) * parse_char(rdi[length - rcx])) to the accumulated value
  ;; for each rcx.
  mov rcx, [.length]
.loop:
  ;; First, calcuate 10^(rcx - 1)
  mov rax, 1

  mov r9, rcx
  .exp_loop:
    dec r9
    jz .break
    mov rbx, 10
    mul rbx
    jmp .exp_loop
  .break:

  ;; Now, rax = 10^(rcx - 1).

  ;; We need to calulate the value of the character at rdi[length - rcx].
  mov rbx, rdi
  add rbx, [.length]
  sub rbx, rcx
  movzx rbx, byte [rbx]
  sub rbx, '0'

  ;; Multiply this value by rax to get (10^(rcx-1) * parse_char(rdi[length - rcx])),
  ;; then add this to the result.
  mul rbx

  ;; Add that value to r8
  add r8, rax

  dec rcx
  jnz .loop

  push r8

  next

READ_NUMBER:
  dq docol
  dq READ_WORD
  dq PARSE_NUMBER
  dq EXIT

;; Takes a string (in the form of a pointer and a length on the stack) and
;; prints it to standard output.
TELL:
  dq .start
.start:
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
TERMINATE:
  dq .start
.start:
  mov rax, $3C
  mov rdi, 0
  syscall

PUSH_HELLO_CHARS:
  dq docol
  dq LIT, $A
  dq LIT, 'o'
  dq LIT, 'l'
  dq LIT, 'l'
  dq LIT, 'e'
  dq LIT, 'H'
  dq EXIT

PUSH_YOU_TYPED:
  dq .start
.start:
  push you_typed_string
  push you_typed_string.length
  next

HELLO_entry:
  dq SPACE_entry
  db 5
  db 'HELLO'
HELLO:
  dq docol
  dq LIT, 'H', EMIT
  dq LIT, 'e', EMIT
  dq LIT, 'l', EMIT
  dq LIT, 'l', EMIT
  dq LIT, 'o', EMIT
  dq LIT, '!', EMIT
  dq NEWLINE
  dq EXIT

;; .U prints the value on the stack as an unsigned integer in hexadecimal.
DOTU_entry:
  dq HELLO_entry
  db 2
  db '.U'
DOTU:
  dq .start
.start:
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

MAIN:
  dq docol
  dq HELLO
  dq LIT, SPACE_entry, DOTU, NEWLINE
  dq LIT, HELLO_entry, DOTU, NEWLINE
  dq LIT, DOTU_entry, DOTU, NEWLINE
  dq LIT, SPACE_string, LIT, SPACE_string.length, TELL, SPACE
  dq LIT, SPACE_string, LIT, SPACE_string.length, FIND, DOTU, NEWLINE
  dq LIT, HELLO_string, LIT, HELLO_string.length, TELL, SPACE
  dq LIT, HELLO_string, LIT, HELLO_string.length, FIND, DOTU, NEWLINE
  dq LIT, DOTU_string, LIT, DOTU_string.length, TELL, SPACE
  dq LIT, DOTU_string, LIT, DOTU_string.length, FIND, DOTU, NEWLINE
  dq LIT, HELLA_string, LIT, HELLA_string.length, TELL, SPACE
  dq LIT, HELLA_string, LIT, HELLA_string.length, FIND, DOTU, NEWLINE
  dq TERMINATE

segment readable writable

latest_entry dq DOTU_entry

SPACE_string db 'SPACE'
.length = $ - SPACE_string
HELLO_string db 'HELLO'
.length = $ - HELLO_string
DOTU_string db '.U'
.length = $ - DOTU_string
HELLA_string db 'HELLA'
.length = $ - HELLA_string


you_typed_string db 'You typed: '
.length = $ - you_typed_string

FIND.search_length dq ?
FIND.search_buffer dq ?
FIND.rsi dq ?

READ_WORD.rsi dq ?
READ_WORD.rax dq ?
READ_WORD.max_size = $FF
READ_WORD.buffer rb READ_WORD.max_size
READ_WORD.length db ?
READ_WORD.char_buffer db ?

DOTU.chars db '0123456789ABCDEF'
DOTU.buffer rq 16               ; 64-bit number has no more than 16 digits in hex
DOTU.rbuffer rq 16
DOTU.length dq ?
DOTU.printed_length dq ?

PARSE_NUMBER.length dq ?

;; Return stack
rq $2000
return_stack_top:
