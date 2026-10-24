#include "isa.h"
// OR: results differ from both operands and from ADD.
.section .text
.globl _start
_start:
    TEST_RR    or, R(0), 0x000000f0, 0x0000003c, 0x000000fc
    TEST_RR    or, R(1), 0x12345678, 0x87654321, 0x97755779
    TEST_RR    or, R(2), 0x80000000, 0x00000001, 0x80000001
    TEST_RR_D1 or, R(3), 0x0f0f0f0f, 0xf0f0f0f0, 0xffffffff
    TEST_RR_X0 or, R(4), 0x00000001, 0x00000002
    TEST_END
