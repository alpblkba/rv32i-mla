#include "isa.h"
// SLTU: unsigned comparison, where 0xffffffff is the largest value; every case with a sign difference gives the opposite of SLT.
.section .text
.globl _start
_start:
    TEST_RR    sltu, R(0), 0xffffffff, 0x00000001, 0x00000000
    TEST_RR    sltu, R(1), 0x00000001, 0xffffffff, 0x00000001
    TEST_RR    sltu, R(2), 0x00000005, 0x00000005, 0x00000000
    TEST_RR    sltu, R(3), 0x80000000, 0x7fffffff, 0x00000000
    TEST_RR    sltu, R(4), 0x7fffffff, 0x80000000, 0x00000001
    TEST_RR    sltu, R(5), 0x00000000, 0x00000001, 0x00000001
    TEST_RR_D1 sltu, R(6), 0x00000000, 0xffffffff, 0x00000001
    TEST_RR_X0 sltu, R(7), 0x00000001, 0x00000002
    TEST_END
