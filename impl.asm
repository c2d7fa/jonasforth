os_code_section

macro printlen msg, len {
  push rsi
  add rsp, 8

  mov rcx, msg
  mov rdx, len
  call os_print_string

  sub rsp, 8
  pop rsi
}

macro newline {
  push $A
  printlen rsp, 1
}

macro print msg {
  printlen msg, msg#.len
}

struc string bytes {
  . db bytes
  .len = $ - .
}

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
  movzx rcx, byte [rsi + 8 + 1]    ; Length of word being looked at
  cmp rcx, [.search_length]
  jne .next    ; If the words don't have the same length, we have the wrong word

  ;; Otherwise, we need to compare strings
  lea rdx, [rsi + 8 + 1 + 1]    ; Location of character being compared in entry
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

;; Read a word from a buffer. Returns the buffer without the word, as well as
;; the word that was read (including lengths).
;;
;; Inputs:
;;   * rsi = Input buffer
;;   * rcx = Length of buffer
;;
;; Outputs:
;;   * rsi = Updated buffer
;;   * rcx = Length of updated buffer
;;   * rdi = Word buffer
;;   * rdx = Length of word buffer
pop_word:
.skip_whitespace:
  mov al, [rsi]
  cmp al, ' '
  je .got_whitespace
  cmp al, $A
  je .got_whitespace
  jmp .alpha
.got_whitespace:
  ;; The buffer starts with whitespace; discard the first character from the buffer.
  inc rsi
  dec rcx
  jmp .skip_whitespace

.alpha:
  ;; We got a character that wasn't whitespace. Now read the actual word.
  mov rdi, rsi ; This is where the word starts
  mov rdx, 1   ; Length of word

.read_alpha:
  ;; Extract character from original buffer:
  inc rsi
  dec rcx

  ;; When we hit whitespace, we are done with this word
  mov al, [rsi]
  cmp al, ' '
  je .end
  cmp al, $A
  je .end

  ;; It wasn't whitespace; add it to word buffer
  inc rdx
  jmp .read_alpha

.end:
  ;; Finally, we want to skip one whitespace character after the word.
  inc rsi
  dec rcx

  ret

;; Parses a string.
;;
;; Parameters:
;;   * rcx = Length of string
;;   * rdi = Pointer to string buffer
;;
;; Results:
;;   * rax = Value
;;
;; Clobbers
parse_number:
  mov r8, 0                     ; Result

  ;; Add (10^(rcx-1) * parse_char(rdi[length - rcx])) to the accumulated value
  ;; for each rcx.
  mov [.length], rcx
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

  cmp rbx, 10
  jae .error

  ;; Multiply this value by rax to get (10^(rcx-1) * parse_char(rdi[length - rcx])),
  ;; then add this to the result.
  mul rbx

  ;; Add that value to r8
  add r8, rax

  dec rcx
  jnz .loop

  mov rax, r8
  ret

.error:
  push rdi
  print parse_number.error_msg
  pop rdi
  printlen rdi, [.length]
  newline
  mov rax, 100
  call os_terminate

os_data_section

find.search_length dq ?
find.search_buffer dq ?

parse_number.length dq ?
parse_number.error_msg string "Invalid number: "

