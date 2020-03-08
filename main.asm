;; vim: syntax=fasm

format ELF64 executable

;; "Syscalls" {{{

;; [NOTE] Volatile registers Linux (syscalls) vs UEFI
;;
;;   Linux syscalls: RAX, RCX, R11
;;   UEFI:           RAX, RCX, R11, RDX, R8, R9, R10

;; We are in the process of replacing our dependency on Linux with a dependency
;; on UEFI. The following macros attempt to isolate what would be syscalls in
;; Linux; thus, we will be able to replace these with UEFI-based implementations,
;; and in theory we should expect the program to work.

;; Print a string of a given length.
;;
;; Input:
;; - RCX = Pointer to buffer
;; - RDX = Buffer length
;;
;; Clobbers: RAX, RCX, R11, RDI, RSI
macro sys_print_string {
  mov rax, 1
  mov rdi, 1
  mov rsi, rcx
  syscall
}

;; }}}

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
macro header label, name, immediate {
  local .string_end

label#_entry:
  dq initial_latest_entry
  if immediate eq
    db 0
  else
    db 1
  end if
  db .string_end - ($ + 1)
  db name
  .string_end:
label:

initial_latest_entry = label#_entry
}

;; Define a Forth word that is implemented in assembly. See 'header' for details.
macro forth_asm label, name, immediate {
  header label, name, immediate
  dq .start
.start:
}

segment readable executable

entry main

include "impl.asm"      ; Misc. subroutines
include "bootstrap.asm" ; Forth words encoded in Assembly

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
  add rax, 8 + 1                ; [rax] = length of name
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

  lea rcx, [rsp]
  mov rdx, 1
  sys_print_string

  add rsp, 8
  popr rax
  popr rsi
  next

;; Read a word and push it onto the stack as a pointer and a size. The pointer
;; is valid until the next call to READ_WORD.
forth_asm READ_WORD, 'READ-WORD'
  ;; Are we reading from user input or from the input buffer?
  cmp [input_buffer], 0
  jne .from_buffer

  ;; Reading user input
  mov [.rsi], rsi

  call read_word
  push rdi                      ; Buffer
  push rdx                      ; Length

  mov rsi, [.rsi]
  next

.from_buffer:
  ;; Reading from buffer
  mov [.rsi], rsi

  mov rsi, [input_buffer]
  mov rcx, [input_buffer_length]

  call pop_word

  mov [input_buffer], rsi        ; Updated buffer
  mov [input_buffer_length], rcx ; Length of updated buffer
  push rdi                       ; Word buffer
  push rdx                       ; Length of word buffer

  mov rsi, [.rsi]
  next

;; Takes a string on the stack and replaces it with the decimal number that the
;; string represents.
forth_asm PARSE_NUMBER, 'PARSE-NUMBER'
  pop rcx     ; Length
  pop rdi     ; String pointer

  push rsi
  call parse_number
  pop rsi

  push rax                      ; Result
  next

;; Takes a string (in the form of a pointer and a length on the stack) and
;; prints it to standard output.
forth_asm TELL, 'TELL'
  pushr rax
  pushr rsi

  pop rdx ; Length
  pop rcx ; Buffer
  sys_print_string

  popr rsi
  popr rax
  next

;; Exit the program cleanly.
forth_asm TERMINATE, 'TERMINATE'
  mov rax, $3C
  mov rdi, 0
  syscall

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

forth_asm NOT_, 'NOT'
  pop rax
  cmp rax, 0
  jz .false
.true:
  push 0
  next
.false:
  push 1
  next

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
  mov rcx, .buffer
  mov rdx, [.printed_length]
  sys_print_string

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

forth_asm PUT_BYTE, 'C!'
  pop rbx
  pop rax                       ; Value
  mov [rbx], al
  next

forth_asm GET_BYTE, 'C@'
  pop rax
  movzx rax, byte [rax]
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

;; Given two integers a and b on the stack, pushes the quotient and remainder of
;; division of a by b.
forth_asm TIMESMOD, '/MOD'
  pop rbx                       ; b
  pop rax                       ; a
  mov rdx, 0
  div rbx
  push rax                      ; a / b
  push rdx                      ; a % b
  next

;; Read input until next " character is found. Push a string containing the
;; input on the stack as (buffer length). Note that the buffer is only valid
;; until the next call to S" and that no more than 255 characters can be read.
forth_asm READ_STRING, 'S"'
  ;; If the input buffer is set, we should read from there instead.
  cmp [input_buffer], 0
  jne read_string_buffer

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

read_string_buffer:
  push rsi

  ;; We borrow READ_STRING's buffer. They won't mind.
  mov [READ_STRING.length], 0

.read_char:
  mov rbx, [input_buffer]
  mov al, [rbx]
  cmp al, '"'
  je .done

  mov rdx, READ_STRING.buffer
  add rdx, [READ_STRING.length]
  mov [rdx], al
  inc [READ_STRING.length]

  inc [input_buffer]
  dec [input_buffer_length]

  jmp .read_char

.done:
  pop rsi

  ;; Skip closing "
  inc [input_buffer]
  dec [input_buffer_length]

  push READ_STRING.buffer
  push [READ_STRING.length]

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
  mov [rdi], byte 0             ; Insert immediate flag

  add rdi, 1
  mov [rdi], byte cl            ; Insert length

  ;; Insert word string
  add rdi, 1

  push rsi
  mov rsi, rdx                  ; rsi = Word string pointer
  rep movsb
  pop rsi

  ;; Update HERE
  mov [here], rdi

  next

forth_asm TICK, "'"
  lodsq
  push rax
  next

forth_asm ROT, 'ROT'
  pop rax
  pop rbx
  pop rdx
  push rax
  push rdx
  push rbx
  next

forth_asm PICK, 'PICK'
  pop rax
  lea rax, [rsp + 8 * rax]
  mov rax, [rax]
  push rax
  next

forth_asm EQL, '='
  pop rax
  pop rbx
  cmp rax, rbx
  je .eq
.noteq:
  push 0
  next
.eq:
  push 1
  next

forth MAIN, 'MAIN'
  dq SYSCODE
  dq INTERPRET_STRING
  dq INTERPRET
  dq BRANCH, -8 * 2
  dq TERMINATE

;; Built-in variables:

forth STATE, 'STATE'
  dq LIT, var_STATE
  dq EXIT

forth LATEST, 'LATEST'
  dq LIT, latest_entry
  dq EXIT

forth HERE, 'HERE'
  dq LIT, here
  dq EXIT

forth SYSCODE, 'SYSCODE'
  dq LIT, sysf
  dq LIT, sysf.len
  dq EXIT

forth INPUT_BUFFER, 'INPUT-BUFFER'
  dq LIT, input_buffer
  dq EXIT

forth INPUT_LENGTH, 'INPUT-LENGTH'
  dq LIT, input_buffer_length
  dq EXIT

segment readable writable

;; The LATEST variable holds a pointer to the word that was last added to the
;; dictionary. This pointer is updated as new words are added, and its value is
;; used by FIND to look up words.
latest_entry dq initial_latest_entry

;; The STATE variable is 0 when the interpreter is executing, and non-zero when
;; it is compiling.
var_STATE dq 0

;; The interpreter can read either from standard input or from a buffer. When
;; input-buffer is set (non-null), words like READ-WORD and S" will use this
;; buffer instead of reading user input.
input_buffer dq 0
input_buffer_length dq 0

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
here_top rq $4000

;; Return stack
rq $2000
return_stack_top:

segment readable

;; We store some Forth code in sys.f that defined common words that the user
;; would expect to have available at startup. To execute these words, we just
;; include the file directly in the binary, and then interpret it at startup.
sysf file 'sys.f'
sysf.len = $ - sysf

