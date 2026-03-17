.section .text
.globl _start

_start:
    addi x1, x0, 5
    addi x2, x0, 7
    add  x3, x1, x2
    sw   x3, 0x100(x0)
    jal  x0, pass
    addi x5, x0, 1

pass:
    addi x5, x0, 2
    sw   x5, 0x104(x0)

loop:
    jal  x0, loop
