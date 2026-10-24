#include "isa.h"
// XOR: results differ from both operands and from OR.
.section .text
.globl _start
_start:
    TEST_RR    xor, R(0), 0x12345678, 0xffffffff, 0xedcba987
    TEST_RR    xor, R(1), 0x0f0f0f0f, 0x00ff00ff, 0x0ff00ff0
    TEST_RR    xor, R(2), 0x80000000, 0x80000001, 0x00000001
    TEST_RR    xor, R(3), 0xa5a5a5a5, 0xa5a5a5a5, 0x00000000
    TEST_RR_D1 xor, R(4), 0x000000f0, 0x0000003c, 0x000000cc
    TEST_RR_X0 xor, R(5), 0x00000001, 0x00000002
    TEST_END
