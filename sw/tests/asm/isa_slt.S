#include "isa.h"
// SLT: signed comparison, where 0xffffffff is -1 and below 1.
.section .text
.globl _start
_start:
    TEST_RR    slt, R(0), 0xffffffff, 0x00000001, 0x00000001
    TEST_RR    slt, R(1), 0x00000001, 0xffffffff, 0x00000000
    TEST_RR    slt, R(2), 0x00000005, 0x00000005, 0x00000000
    TEST_RR    slt, R(3), 0x80000000, 0x7fffffff, 0x00000001
    TEST_RR    slt, R(4), 0x7fffffff, 0x80000000, 0x00000000
    TEST_RR    slt, R(5), 0x00000004, 0x00000005, 0x00000001
    TEST_RR_D1 slt, R(6), 0xfffffffe, 0xffffffff, 0x00000001
    TEST_RR_X0 slt, R(7), 0x00000001, 0x00000002
    TEST_END
