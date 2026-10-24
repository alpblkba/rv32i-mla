#include "isa.h"
// BLT: signed less than, so -1 is below 1 and 0x80000000 is the smallest value.
.section .text
.globl _start
_start:
    TEST_BR        blt, R(0), 0xffffffff, 0x00000001, 1
    TEST_BR        blt, R(1), 0x00000001, 0xffffffff, 0
    TEST_BR        blt, R(2), 0x00000005, 0x00000005, 0
    TEST_BR        blt, R(3), 0x80000000, 0x7fffffff, 1
    TEST_BR        blt, R(4), 0x7fffffff, 0x80000000, 0
    TEST_BR        blt, R(5), 0xfffffffe, 0xffffffff, 1
    TEST_BRB       blt, R(6), 0xffffffff, 0x00000000, 1
    TEST_BRB       blt, R(7), 0x00000000, 0xffffffff, 0
    TEST_BR_NT_ODD blt, R(8), 0x00000005, 0x00000004
    TEST_END
