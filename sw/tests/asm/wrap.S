# Builds 0x80000000 by doubling -2048 twenty times, then checks signed overflow in both directions.
.section .text
.globl _start

_start:
    addi x1, x0, -2048
    .rept 20
    add  x1, x1, x1
    .endr
    sw   x1, 0x100(x0)       # 0x80000000
    addi x2, x1, -1          # 0x7fffffff
    sw   x2, 0x104(x0)
    addi x3, x2, 1           # 0x80000000
    sw   x3, 0x108(x0)
    add  x4, x1, x1          # 0x00000000, plus 3 below
    addi x4, x4, 3
    sw   x4, 0x10c(x0)
    sub  x5, x0, x1          # 0x80000000
    sw   x5, 0x110(x0)
    sub  x6, x1, x2          # 0x00000001
    sw   x6, 0x114(x0)
    ecall

loop:
    jal  x0, loop
