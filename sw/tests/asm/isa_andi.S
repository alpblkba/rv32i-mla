#include "isa.h"
// ANDI: the immediate is sign extended, so -16 keeps bits 31:4 and 2047 keeps only bits 10:0.
.section .text
.globl _start
_start:
    TEST_RI    andi, R(0), 0x12345678, 0x0f0, 0x00000070
    TEST_RI    andi, R(1), 0x12345678, -16, 0x12345670
    TEST_RI    andi, R(2), 0x12345678, -2048, 0x12345000
    TEST_RI    andi, R(3), 0xffffffff, 2047, 0x000007ff
    TEST_RI_D1 andi, R(4), 0xf0f0f0f0, 0x0ff, 0x000000f0
    TEST_RI_X0 andi, R(5), 0xffffffff, -1
    TEST_END
