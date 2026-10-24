#include "isa.h"
// SLLI: shift amounts 0, 1, 4 and 31 from the 5-bit shamt field.
.section .text
.globl _start
_start:
    TEST_RI    slli, R(0), 0x00000001, 31, 0x80000000
    TEST_RI    slli, R(1), 0x12345678, 4, 0x23456780
    TEST_RI    slli, R(2), 0x12345678, 0, 0x12345678
    TEST_RI    slli, R(3), 0x80000001, 1, 0x00000002
    TEST_RI_D1 slli, R(4), 0x00000003, 2, 0x0000000c
    TEST_RI_X0 slli, R(5), 0x00000001, 1
    TEST_END
