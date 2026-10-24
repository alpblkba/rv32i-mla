#include "isa.h"
// BNE: taken when any of the 32 bits differ, including only bit 31 or only bit 0.
.section .text
.globl _start
_start:
    TEST_BR        bne, R(0), 0x00000005, 0x00000006, 1
    TEST_BR        bne, R(1), 0x00000005, 0x00000005, 0
    TEST_BR        bne, R(2), 0x80000000, 0x00000000, 1
    TEST_BR        bne, R(3), 0xfffffffe, 0xffffffff, 1
    TEST_BR        bne, R(4), 0x00000000, 0x00000000, 0
    TEST_BRB       bne, R(5), 0x00000001, 0x00000002, 1
    TEST_BRB       bne, R(6), 0x00000002, 0x00000002, 0
    TEST_BR_NT_ODD bne, R(7), 0x00000003, 0x00000003
    TEST_END
