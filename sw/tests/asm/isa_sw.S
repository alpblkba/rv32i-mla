#include "isa.h"
// SW: a full word replaces all four bytes, from x0 and through a base register with a negative offset, and storing x0 writes zero.
.section .text
.globl _start
_start:
    TEST_ST  sw, R(0), 0xa1b2c3d4, 0x12345678, 0, 0x12345678
    TEST_STB sw, R(1), 0xa1b2c3d4, 0x89abcdef, 0, 0x89abcdef
    .pushsection .rodata
    .balign 4
1:  .word 0xa1b2c3d4
    .popsection
    lw   x1, %lo(1b)(x0)
    sw   x1, R(2)(x0)
    sw   x0, R(2)(x0)
    EXPECT R(2), 0x00000000
    TEST_END
