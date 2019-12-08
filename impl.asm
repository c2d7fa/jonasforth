segment readable executable

;; Find the given word in the dictionary of words. If no such word exists,
;; return 0.
;;
;; Parameters:
;;   * [find.search_length] = Length of the word in bytes.
;;   * [find.search_buffer] = Pointer to the string containing the word.
;;   * rsi = Pointer to the last entry in the dictionary.
;;
;; Results:
;;   * rsi = Pointer to the found entry in the dictionary or 0.
;;
;; Clobbers rcx, rdx, rdi, rax.
find:
  ;; RSI contains the entry we are currently looking at
.loop:
  movzx rcx, byte [rsi + 16]    ; Length of word being looked at
  cmp rcx, [.search_length]
  jne .next    ; If the words don't have the same length, we have the wrong word

  ;; Otherwise, we need to compare strings
  lea rdx, [rsi + 16 + 1]       ; Location of character being compared in entry
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
  ret

;; Read a word from standard input. Returns pointer to string containing word as
;; well as length.
;;
;; Results:
;;   * rdx = Length of string
;;   * rdi = Pointer to string buffer
;;
;; Clobbers pretty much everything.
read_word:
.skip_whitespace:
  ;; Read characters into .char_buffer until one of them is not whitespace.
  mov rax, 0
  mov rdi, 0
  mov rsi, .char_buffer
  mov rdx, 1
  syscall

  ;; We consider newlines and spaces to be whitespace.
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
  mov rdi, .buffer
  movzx rdx, [.length]

  ret

;; Parses a string.
;;
;; Parameters:
;;   * [.length] = Length of string
;;   * [.buffer] = Pointer to string buffer
;;
;; Results:
;;   * rax = Value
;;
;; Clobbers
parse_number:
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

  mov rax, r8
  ret


segment readable writable

find.search_length dq ?
find.search_buffer dq ?

read_word.max_size = $FF
read_word.buffer rb read_word.max_size
read_word.length db ?
read_word.char_buffer db ?

parse_number.buffer dq ?
parse_number.length dq ?

