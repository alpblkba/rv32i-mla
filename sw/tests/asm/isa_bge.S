#include "isa.h"
// BGE: signed greater or equal, the complement of BLT, and taken on equal operands.
.section .text
.globl _start
_start:
    TEST_BR        bge, R(0), 0xffffffff, 0x00000001, 0
    TEST_BR        bge, R(1), 0x00000001, 0xffffffff, 1
    TEST_BR        bge, R(2), 0x00000005, 0x00000005, 1
    TEST_BR        bge, R(3), 0x80000000, 0x7fffffff, 0
    TEST_BR        bge, R(4), 0x7fffffff, 0x80000000, 1
    TEST_BR        bge, R(5), 0x00000004, 0x00000005, 0
    TEST_BRB       bge, R(6), 0x00000000, 0xffffffff, 1
    TEST_BRB       bge, R(7), 0xffffffff, 0x00000000, 0
    TEST_BR_NT_ODD bge, R(8), 0x00000004, 0x00000005
    TEST_END
