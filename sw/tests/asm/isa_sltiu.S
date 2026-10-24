#include "isa.h"
// SLTIU: the immediate is sign extended and then compared unsigned, so -1 is 0xffffffff and sltiu rd, rs1, 1 tests rs1 == 0.
.section .text
.globl _start
_start:
    TEST_RI    sltiu, R(0), 0x00000000, 1, 0x00000001
    TEST_RI    sltiu, R(1), 0x00000001, 1, 0x00000000
    TEST_RI    sltiu, R(2), 0xfffffffe, -1, 0x00000001
    TEST_RI    sltiu, R(3), 0xffffffff, -1, 0x00000000
    TEST_RI    sltiu, R(4), 0x000007ff, 2047, 0x00000000
    TEST_RI    sltiu, R(5), 0x000007fe, 2047, 0x00000001
    TEST_RI    sltiu, R(6), 0x80000000, -2048, 0x00000001
    TEST_RI_D1 sltiu, R(7), 0x00000005, 6, 0x00000001
    TEST_RI_X0 sltiu, R(8), 0x00000000, 1
    TEST_END
