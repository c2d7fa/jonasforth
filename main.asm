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
    mov [rbp], x
}
macro popr x {
    mov x, [rbp]
    add rbp, 8
}

segment readable executable

start:
    ;; Initialize return stack
    mov rbp, return_stack_top

    jmp $

segment readable

segment readable writable

;; Return stack
rq $2000
return_stack_top:
