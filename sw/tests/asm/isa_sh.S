#include "isa.h"
// SH: rs2[15:0] goes to the halfword that addr[1] selects and the other halfword keeps its value, from x0 and through a base register with a negative offset.
.section .text
.globl _start
_start:
    TEST_ST  sh, R(0), 0xa1b2c3d4, 0xdead8e5a, 0, 0xa1b28e5a
    TEST_ST  sh, R(1), 0xa1b2c3d4, 0xdead8e5a, 2, 0x8e5ac3d4
    TEST_ST  sh, R(2), 0xa1b2c3d4, 0x0000f00f, 0, 0xa1b2f00f
    TEST_STB sh, R(3), 0xa1b2c3d4, 0xdead8e5a, 2, 0x8e5ac3d4
    TEST_END
