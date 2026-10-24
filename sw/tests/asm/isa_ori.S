#include "isa.h"
// ORI: the immediate is sign extended, so -2048 sets bits 31:11.
.section .text
.globl _start
_start:
    TEST_RI    ori, R(0), 0x12345678, 0x0f0, 0x123456f8
    TEST_RI    ori, R(1), 0x12345678, -2048, 0xfffffe78
    TEST_RI    ori, R(2), 0x00000000, -1, 0xffffffff
    TEST_RI    ori, R(3), 0x80000000, 1, 0x80000001
    TEST_RI_D1 ori, R(4), 0x00000f00, 0x00f, 0x00000f0f
    TEST_RI_X0 ori, R(5), 0x00000001, 2
    TEST_END
