#include "isa.h"
// LUI: the immediate fills bits 31:12 and bits 11:0 become zero, and rd equal to x0 changes nothing.
.section .text
.globl _start
_start:
    TEST_LUI R(0), 0x12345, 0x12345000
    TEST_LUI R(1), 0x80000, 0x80000000
    TEST_LUI R(2), 0xfffff, 0xfffff000
    TEST_LUI R(3), 0x00001, 0x00001000
    TEST_LUI R(4), 0x00000, 0x00000000
    lui  x0, 0x12345
    CHECK x0, R(5), 0
    TEST_END
