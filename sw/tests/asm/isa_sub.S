#include "isa.h"
// SUB: borrow into bit 31, the result differs from ADD of the same operands.
.section .text
.globl _start
_start:
    TEST_RR    sub, R(0), 0x00000000, 0x00000001, 0xffffffff
    TEST_RR    sub, R(1), 0x80000000, 0x00000001, 0x7fffffff
    TEST_RR    sub, R(2), 0x12345678, 0x87654321, 0x8acf1357
    TEST_RR    sub, R(3), 0x00000005, 0x00000005, 0x00000000
    TEST_RR_D1 sub, R(4), 0x00001000, 0x00000001, 0x00000fff
    TEST_RR_X0 sub, R(5), 0x00000001, 0x00000002
    TEST_END
