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

segment readable executable

start:
    jmp $

segment readable
