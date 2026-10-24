#include "isa.h"
// ADD: carries out of bit 31, wraparound, rd equal to rs1 and rd equal to x0.
.section .text
.globl _start
_start:
    TEST_RR    add, R(0), 0x7fffffff, 0x00000001, 0x80000000
    TEST_RR    add, R(1), 0xffffffff, 0xffffffff, 0xfffffffe
    TEST_RR    add, R(2), 0x12345678, 0x87654321, 0x99999999
    TEST_RR    add, R(3), 0x80000000, 0x80000000, 0x00000000
    TEST_RR_D1 add, R(4), 0x00000fff, 0x00000001, 0x00001000
    TEST_RR_X0 add, R(5), 0x00000001, 0x00000002
    TEST_END
