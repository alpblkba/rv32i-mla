# Taken and not taken BEQ and BNE, backward branches and a backward jal. Each wrong path leaves a different value in its result word.
.section .text
.globl _start

_start:
    addi x1, x0, 5
    addi x2, x0, 0
1:  addi x2, x2, 3
    addi x1, x1, -1
    bne  x1, x0, 1b          # backward, taken four times
    sw   x2, 0x100(x0)       # 15

    addi x3, x0, 0
    addi x4, x0, 1
2:  addi x3, x3, 1
    beq  x3, x4, 2b          # backward, taken once
    sw   x3, 0x104(x0)       # 2

    addi x5, x0, 0x11
    beq  x3, x4, 3f          # not taken
    addi x5, x5, 0x10
3:  sw   x5, 0x108(x0)       # 0x21

    addi x6, x0, 0x22
    bne  x4, x4, 4f          # not taken
    addi x6, x6, 0x10
4:  sw   x6, 0x10c(x0)       # 0x32

    addi x7, x0, 0x33
    beq  x4, x4, 5f          # taken
    addi x7, x7, 0x10
5:  sw   x7, 0x110(x0)       # 0x33

    addi x8, x0, 0x44
    bne  x3, x4, 6f          # taken
    addi x8, x8, 0x10
6:  sw   x8, 0x114(x0)       # 0x44

    # 0xfffff800 and 0x00000800 have the same low 12 bits, so a narrow comparator would see them as equal.
    addi x9, x0, -2048
    addi x10, x0, 1024
    add  x10, x10, x10
    addi x11, x0, 0x55
    beq  x9, x10, 7f         # not taken
    addi x11, x11, 0x10
7:  sw   x11, 0x118(x0)      # 0x65
    addi x12, x0, 0x66
    bne  x9, x10, 8f         # taken
    addi x12, x12, 0x10
8:  sw   x12, 0x11c(x0)      # 0x66

    jal  x0, 10f
9:  addi x13, x0, 0x77
    jal  x0, 11f
10: jal  x0, 9b              # backward
11: sw   x13, 0x120(x0)      # 0x77
    ecall

loop:
    jal  x0, loop
