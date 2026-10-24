#include "isa.h"
// SLTI: signed comparison with the sign-extended immediate.
.section .text
.globl _start
_start:
    TEST_RI    slti, R(0), 0xffffffff, 0, 0x00000001
    TEST_RI    slti, R(1), 0x00000000, -1, 0x00000000
    TEST_RI    slti, R(2), 0x7fffffff, -2048, 0x00000000
    TEST_RI    slti, R(3), 0x80000000, 2047, 0x00000001
    TEST_RI    slti, R(4), 0x00000005, 5, 0x00000000
    TEST_RI    slti, R(5), 0x00000004, 5, 0x00000001
    TEST_RI    slti, R(6), 0xfffff7ff, -2048, 0x00000001
    TEST_RI_D1 slti, R(7), 0xfffffffe, -1, 0x00000001
    TEST_RI_X0 slti, R(8), 0xffffffff, 0
    TEST_END
