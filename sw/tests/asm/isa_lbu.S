#include "isa.h"
// LBU: each of the four bytes of 0x80ff7f01, zero extended, and a load through a base register with a negative offset.
.section .text
.globl _start
_start:
    TEST_LD  lbu, R(0), 0x80ff7f01, 0, 0x00000001
    TEST_LD  lbu, R(1), 0x80ff7f01, 1, 0x0000007f
    TEST_LD  lbu, R(2), 0x80ff7f01, 2, 0x000000ff
    TEST_LD  lbu, R(3), 0x80ff7f01, 3, 0x00000080
    TEST_LDB lbu, R(4), 0x80ff7f01, 2, 0x000000ff
    TEST_END
