#include "isa.h"
// XORI: the immediate is sign extended, so -1 inverts every bit and -2048 flips bits 31:11.
.section .text
.globl _start
_start:
    TEST_RI    xori, R(0), 0x12345678, 0x0ff, 0x12345687
    TEST_RI    xori, R(1), 0x12345678, -1, 0xedcba987
    TEST_RI    xori, R(2), 0x12345678, -2048, 0xedcbae78
    TEST_RI    xori, R(3), 0x00000000, 2047, 0x000007ff
    TEST_RI_D1 xori, R(4), 0xffffffff, 0x0f0, 0xffffff0f
    TEST_RI_X0 xori, R(5), 0x00000001, 1
    TEST_END
