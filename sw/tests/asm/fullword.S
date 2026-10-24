# Builds 0x12345678 with addi and doubling add, stores it, loads it back and stores the loaded copy, then stores its negation 0xedcba988.
.section .text
.globl _start

_start:
    addi x1, x0, 0x123
    .rept 12
    add  x1, x1, x1
    .endr
    addi x1, x1, 0x456
    .rept 8
    add  x1, x1, x1
    .endr
    addi x1, x1, 0x78
    sw   x1, 0x100(x0)
    lw   x2, 0x100(x0)
    sw   x2, 0x104(x0)
    sub  x3, x0, x1
    sw   x3, 0x108(x0)
    ecall

loop:
    jal  x0, loop
