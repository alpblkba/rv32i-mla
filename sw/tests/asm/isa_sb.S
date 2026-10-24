#include "isa.h"
// SB: rs2[7:0] goes to the byte that addr[1:0] selects and the other three bytes keep their value, from x0 and through a base register with a negative offset.
.section .text
.globl _start
_start:
    TEST_ST  sb, R(0), 0xa1b2c3d4, 0xdeadbe5a, 0, 0xa1b2c35a
    TEST_ST  sb, R(1), 0xa1b2c3d4, 0xdeadbe5a, 1, 0xa1b25ad4
    TEST_ST  sb, R(2), 0xa1b2c3d4, 0xdeadbe5a, 2, 0xa15ac3d4
    TEST_ST  sb, R(3), 0xa1b2c3d4, 0xdeadbe5a, 3, 0x5ab2c3d4
    TEST_ST  sb, R(4), 0xa1b2c3d4, 0x000000f0, 1, 0xa1b2f0d4
    TEST_STB sb, R(5), 0xa1b2c3d4, 0xdeadbe5a, 3, 0x5ab2c3d4
    TEST_END
