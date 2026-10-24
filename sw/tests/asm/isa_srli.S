#include "isa.h"
// SRLI: logical right shift by 0, 1, 4 and 31.
.section .text
.globl _start
_start:
    TEST_RI    srli, R(0), 0x80000000, 31, 0x00000001
    TEST_RI    srli, R(1), 0x80000000, 1, 0x40000000
    TEST_RI    srli, R(2), 0xffffffff, 4, 0x0fffffff
    TEST_RI    srli, R(3), 0x12345678, 0, 0x12345678
    TEST_RI_D1 srli, R(4), 0x000000f0, 4, 0x0000000f
    TEST_RI_X0 srli, R(5), 0x80000000, 1
    TEST_END
