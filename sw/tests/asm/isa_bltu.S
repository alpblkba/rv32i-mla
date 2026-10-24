#include "isa.h"
// BLTU: unsigned less than, so 0xffffffff is the largest value; every case with a sign difference gives the opposite of BLT.
.section .text
.globl _start
_start:
    TEST_BR        bltu, R(0), 0xffffffff, 0x00000001, 0
    TEST_BR        bltu, R(1), 0x00000001, 0xffffffff, 1
    TEST_BR        bltu, R(2), 0x00000005, 0x00000005, 0
    TEST_BR        bltu, R(3), 0x80000000, 0x7fffffff, 0
    TEST_BR        bltu, R(4), 0x7fffffff, 0x80000000, 1
    TEST_BR        bltu, R(5), 0x00000000, 0x00000001, 1
    TEST_BRB       bltu, R(6), 0x00000000, 0xffffffff, 1
    TEST_BRB       bltu, R(7), 0xffffffff, 0x00000000, 0
    TEST_BR_NT_ODD bltu, R(8), 0x00000005, 0x00000004
    TEST_END
