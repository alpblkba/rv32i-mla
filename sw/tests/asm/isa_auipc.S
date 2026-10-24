#include "isa.h"
// AUIPC: rd is the address of the auipc plus the immediate shifted left by 12, wrapping at 32 bits. The expected words are link-time expressions of the instruction's own label.
.section .text
.globl _start
_start:
    .pushsection .rodata
    .balign 4
9:  .word SENTINEL
    .popsection
    lw   x3, %lo(9b)(x0)
1:  auipc x3, 0
    CHECK x3, R(0), 1b
    lw   x3, %lo(9b)(x0)
2:  auipc x3, 0x00001
    CHECK x3, R(1), 2b + 0x1000
    lw   x3, %lo(9b)(x0)
3:  auipc x3, 0x80000
    CHECK x3, R(2), 3b + 0x80000000
    lw   x3, %lo(9b)(x0)
4:  auipc x3, 0xfffff
    CHECK x3, R(3), 4b - 0x1000
    auipc x0, 0x12345
    CHECK x0, R(4), 0
    TEST_END
