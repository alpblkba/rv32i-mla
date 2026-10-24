#include "isa.h"
// JAL: rd receives the address after the jal, forward and backward offsets, a jump over 256 bytes of zero words, and rd equal to x0. A backward offset sets imm[20], imm[19:12] and imm[11].
.section .text
.globl _start
_start:
    .pushsection .rodata
    .balign 4
9:  .word SENTINEL
    .popsection
    lw   x5, %lo(9b)(x0)
    addi x6, x0, 2
    jal  x5, 1f
10: addi x6, x0, 1
1:  CHECK x5, R(0), 10b
    CHECK x6, R(1), 2

    lw   x8, %lo(9b)(x0)
    jal  x0, 3f
2:  addi x7, x0, 0x22
    jal  x0, 4f
3:  jal  x8, 2b
11:
4:  CHECK x7, R(2), 0x22
    CHECK x8, R(3), 11b

    lw   x10, %lo(9b)(x0)
    jal  x10, 6f
12: .skip 0x100
6:  CHECK x10, R(4), 12b

    addi x11, x0, 0x11
    jal  x0, 7f
    addi x11, x0, 0x7bd
7:  CHECK x11, R(5), 0x11
    TEST_END
