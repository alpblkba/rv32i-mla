#include "isa.h"
// BGEU: unsigned greater or equal, the complement of BLTU, and taken on equal operands.
.section .text
.globl _start
_start:
    TEST_BR        bgeu, R(0), 0xffffffff, 0x00000001, 1
    TEST_BR        bgeu, R(1), 0x00000001, 0xffffffff, 0
    TEST_BR        bgeu, R(2), 0x00000005, 0x00000005, 1
    TEST_BR        bgeu, R(3), 0x80000000, 0x7fffffff, 1
    TEST_BR        bgeu, R(4), 0x00000000, 0x00000001, 0
    TEST_BRB       bgeu, R(5), 0xffffffff, 0x00000000, 1
    TEST_BRB       bgeu, R(6), 0x00000000, 0xffffffff, 0
    TEST_BR_NT_ODD bgeu, R(7), 0x00000001, 0x00000002
    TEST_END
