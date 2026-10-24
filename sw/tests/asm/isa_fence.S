#include "isa.h"
// FENCE: runs as a NOP whatever its fields hold, so x5 and x6 keep their values even when the encoding names them as rd and rs1.
.section .text
.globl _start
_start:
    .pushsection .rodata
    .balign 4
9:  .word 0x13579bdf, 0x2468ace0
    .popsection
    lw   x5, %lo(9b)(x0)
    lw   x6, %lo(9b + 4)(x0)
    fence
    fence rw, rw
    fence iorw, iorw
    fence.tso
    .insn i 0x0f, 0, x5, x6, -1  # FENCE with rd x5, rs1 x6 and every fm, pred and succ bit set
    CHECK x5, R(0), 0x13579bdf
    CHECK x6, R(1), 0x2468ace0
    TEST_END
