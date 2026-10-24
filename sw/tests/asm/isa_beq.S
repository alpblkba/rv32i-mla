#include "isa.h"
// BEQ: taken only when all 32 bits match; operands that differ only in bit 31 or only in bit 0 must not branch.
.section .text
.globl _start
_start:
    TEST_BR        beq, R(0), 0x00000005, 0x00000005, 1
    TEST_BR        beq, R(1), 0x00000005, 0x00000006, 0
    TEST_BR        beq, R(2), 0x80000000, 0x00000000, 0
    TEST_BR        beq, R(3), 0xfffffffe, 0xffffffff, 0
    TEST_BR        beq, R(4), 0xffffffff, 0xffffffff, 1
    TEST_BRB       beq, R(5), 0x00000007, 0x00000007, 1
    TEST_BRB       beq, R(6), 0x00000007, 0x00000008, 0
    TEST_BR_NT_ODD beq, R(7), 0x00000001, 0x00000002
    TEST_END
