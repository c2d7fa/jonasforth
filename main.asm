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
EXIT:
  dq .start
.start:
  popr rsi
  next

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

TYPE:
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

PUSH_HELLO_CHARS:
  dq .start
.start:
  push $A
  push 'o'
  push 'l'
  push 'l'
  push 'e'
  push 'H'
  next

PUSH_TEST_STRING:
  dq .start
.start:
  push test_string
  push test_string.length
  next

HELLO:
  dq docol
  dq PUSH_HELLO_CHARS
  dq EMIT
  dq EMIT
  dq EMIT
  dq EMIT
  dq EMIT
  dq EMIT
  dq EXIT

TERMINATE:
  dq .start
  .start:
  mov rax, $3C
  mov rdi, 0
  syscall

MAIN:
  dq docol
  dq HELLO
  dq PUSH_TEST_STRING
  dq PUSH_TEST_STRING
  dq TYPE
  dq TYPE
  dq HELLO
  dq HELLO
  dq TERMINATE

segment readable writable

test_string db 'Hi, this is a test.',$A
.length = $ - test_string

;; Return stack
rq $2000
return_stack_top:
