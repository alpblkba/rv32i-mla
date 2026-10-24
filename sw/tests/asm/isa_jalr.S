#include "isa.h"
// JALR: the target is rs1 plus the sign-extended immediate with bit 0 cleared, and rd receives the address after the jalr. Each case stores 2 on the target path and 1 on the fall through path.
.section .text
.globl _start
_start:
    .pushsection .rodata
    .balign 4
9:  .word SENTINEL
    .popsection

    lw   x5, %lo(9b)(x0)
    addi x1, x0, %lo(1f)
    addi x6, x0, 1
    jalr x5, 0(x1)
10: jal  x0, 2f
1:  addi x6, x0, 2
2:  CHECK x6, R(0), 2
    CHECK x5, R(1), 10b

    lw   x5, %lo(9b)(x0)
    addi x1, x0, %lo(3f + 16)
    addi x6, x0, 1
    jalr x5, -16(x1)
11: jal  x0, 4f
3:  addi x6, x0, 2
4:  CHECK x6, R(2), 2
    CHECK x5, R(3), 11b

    lw   x5, %lo(9b)(x0)
    addi x1, x0, %lo(5f)
    addi x6, x0, 1
    jalr x5, 1(x1)               # target 5f + 1, bit 0 cleared, no trap
12: jal  x0, 6f
5:  addi x6, x0, 2
6:  CHECK x6, R(4), 2
    CHECK x5, R(5), 12b

    addi x1, x0, %lo(7f)
    addi x1, x1, -0x7f0
    addi x6, x0, 1
    jalr x1, 0x7f0(x1)           # rd equal to rs1: the target uses the old value
13: jal  x0, 8f
7:  addi x6, x0, 2
8:  CHECK x6, R(6), 2
    CHECK x1, R(7), 13b

    addi x1, x0, %lo(14f)
    addi x6, x0, 1
    jalr x0, 0(x1)
    jal  x0, 15f
14: addi x6, x0, 2
15: CHECK x6, R(8), 2
    CHECK x0, R(9), 0
    TEST_END
