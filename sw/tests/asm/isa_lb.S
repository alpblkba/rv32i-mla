#include "isa.h"
// LB: each of the four bytes of 0x80ff7f01, sign extended from bit 7, and a load through a base register with a negative offset.
.section .text
.globl _start
_start:
    TEST_LD  lb, R(0), 0x80ff7f01, 0, 0x00000001
    TEST_LD  lb, R(1), 0x80ff7f01, 1, 0x0000007f
    TEST_LD  lb, R(2), 0x80ff7f01, 2, 0xffffffff
    TEST_LD  lb, R(3), 0x80ff7f01, 3, 0xffffff80
    TEST_LDB lb, R(4), 0x80ff7f01, 3, 0xffffff80
    TEST_LDB lb, R(5), 0x80ff7f01, 1, 0x0000007f
    TEST_END
