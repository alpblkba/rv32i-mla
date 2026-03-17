.section .text
.globl _start

_start:
    addi x1, x0, 12
    sw   x1, 0x100(x0)

loop:
    jal  x0, loop
