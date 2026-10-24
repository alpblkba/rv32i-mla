#include "isa.h"
// LHU: both aligned halfwords of two words, zero extended, and a load through a base register with a negative offset.
.section .text
.globl _start
_start:
    TEST_LD  lhu, R(0), 0x80ff7f01, 0, 0x00007f01
    TEST_LD  lhu, R(1), 0x80ff7f01, 2, 0x000080ff
    TEST_LD  lhu, R(2), 0x7fff8000, 0, 0x00008000
    TEST_LD  lhu, R(3), 0x7fff8000, 2, 0x00007fff
    TEST_LDB lhu, R(4), 0x80ff7f01, 2, 0x000080ff
    TEST_END
