#include "isa.h"
// ADDI: the 12-bit immediate is sign extended, from -2048 to 2047, and the sum wraps at 32 bits.
.section .text
.globl _start
_start:
    TEST_RI    addi, R(0), 0x7fffffff, 1, 0x80000000
    TEST_RI    addi, R(1), 0x80000000, -1, 0x7fffffff
    TEST_RI    addi, R(2), 0x00000000, -2048, 0xfffff800
    TEST_RI    addi, R(3), 0x12345678, 2047, 0x12345e77
    TEST_RI    addi, R(4), 0xffffffff, 1, 0x00000000
    TEST_RI_D1 addi, R(5), 0x00000010, -16, 0x00000000
    TEST_RI_X0 addi, R(6), 0x00000001, 1
    TEST_END
