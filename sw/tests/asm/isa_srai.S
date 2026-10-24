#include "isa.h"
// SRAI: arithmetic right shift by 0, 1, 4 and 31; negative values give a different result from SRLI.
.section .text
.globl _start
_start:
    TEST_RI    srai, R(0), 0x80000000, 1, 0xc0000000
    TEST_RI    srai, R(1), 0x80000000, 31, 0xffffffff
    TEST_RI    srai, R(2), 0x7fffffff, 4, 0x07ffffff
    TEST_RI    srai, R(3), 0x87654321, 0, 0x87654321
    TEST_RI_D1 srai, R(4), 0xffffff00, 4, 0xfffffff0
    TEST_RI_X0 srai, R(5), 0x80000000, 1
    TEST_END
