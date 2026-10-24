# ADD, SUB, AND, OR and ADDI on negative values and on carries out of bit 31, then writes to x0 that must not stick.
.section .text
.globl _start

_start:
    addi x1, x0, 2047        # 0x000007ff
    addi x2, x0, -2048       # 0xfffff800, sign extended immediate
    sw   x1, 0x100(x0)
    sw   x2, 0x104(x0)
    add  x3, x1, x2          # 0xffffffff
    sw   x3, 0x108(x0)
    sub  x4, x2, x1          # 0xfffff001
    sw   x4, 0x10c(x0)
    sub  x5, x1, x2          # 0x00000fff
    sw   x5, 0x110(x0)
    addi x6, x3, 5           # 0xffffffff + 5 wraps to 0x00000004
    sw   x6, 0x114(x0)
    add  x7, x3, x3          # 0xfffffffe
    sw   x7, 0x118(x0)
    sub  x8, x0, x1          # 0xfffff801
    sw   x8, 0x11c(x0)
    addi x9, x0, 0x0f0
    addi x10, x0, 0x03c
    and  x11, x9, x10        # 0x00000030
    or   x12, x9, x10        # 0x000000fc
    sw   x11, 0x120(x0)
    sw   x12, 0x124(x0)
    and  x13, x4, x5         # 0x00000001
    or   x14, x4, x5         # 0xffffffff
    sw   x13, 0x128(x0)
    sw   x14, 0x12c(x0)
    addi x0, x0, 5
    add  x0, x1, x1
    lw   x0, 0x100(x0)
    addi x15, x0, 0x77       # 0x00000077 only if x0 is still 0
    add  x16, x0, x1         # 0x000007ff only if x0 is still 0
    sw   x15, 0x130(x0)
    sw   x16, 0x134(x0)
    ecall

loop:
    jal  x0, loop
