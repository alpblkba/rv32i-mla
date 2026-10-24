# The two instructions after the jal must be skipped: if they run, 0x104 holds 1 and 0x108 holds 1 instead of 2 and 0. The link register x6 is stored at 0x10c and must hold 0x18, the address after the jal.
.section .text
.globl _start

_start:
    addi x1, x0, 5
    addi x2, x0, 7
    add  x3, x1, x2
    sw   x3, 0x100(x0)
    addi x5, x0, 2
    jal  x6, pass          # at 0x14
    addi x5, x0, 1
    sw   x5, 0x108(x0)

pass:
    sw   x5, 0x104(x0)
    sw   x6, 0x10c(x0)
    ecall

loop:
    jal  x0, loop
