#include "isa.h"
// LH: both aligned halfwords of two words, sign extended from bit 15, and a load through a base register with a negative offset.
.section .text
.globl _start
_start:
    TEST_LD  lh, R(0), 0x80ff7f01, 0, 0x00007f01
    TEST_LD  lh, R(1), 0x80ff7f01, 2, 0xffff80ff
    TEST_LD  lh, R(2), 0x7fff8000, 0, 0xffff8000
    TEST_LD  lh, R(3), 0x7fff8000, 2, 0x00007fff
    TEST_LDB lh, R(4), 0x7fff8000, 0, 0xffff8000
    TEST_END
