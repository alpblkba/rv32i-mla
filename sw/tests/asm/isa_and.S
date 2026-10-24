#include "isa.h"
// AND: results differ from both operands.
.section .text
.globl _start
_start:
    TEST_RR    and, R(0), 0x000000f0, 0x0000003c, 0x00000030
    TEST_RR    and, R(1), 0x12345678, 0x87654321, 0x02244220
    TEST_RR    and, R(2), 0xffffffff, 0x80000001, 0x80000001
    TEST_RR_D1 and, R(3), 0x0f0f0f0f, 0x00ff00ff, 0x000f000f
    TEST_RR_X0 and, R(4), 0xffffffff, 0xffffffff
    TEST_END
