#include "isa.h"
// SLL: shift amounts 0, 1, 4 and 31, and only rs2[4:0] counts, so 32 and 0xffffffe4 shift by 0 and 4.
.section .text
.globl _start
_start:
    TEST_RR    sll, R(0), 0x00000001, 0x0000001f, 0x80000000
    TEST_RR    sll, R(1), 0x12345678, 0x00000004, 0x23456780
    TEST_RR    sll, R(2), 0x12345678, 0xffffffe4, 0x23456780
    TEST_RR    sll, R(3), 0x12345678, 0x00000000, 0x12345678
    TEST_RR    sll, R(4), 0x80000001, 0x00000001, 0x00000002
    TEST_RR    sll, R(5), 0x12345678, 0x00000020, 0x12345678
    TEST_RR_D1 sll, R(6), 0x00000003, 0x00000002, 0x0000000c
    TEST_RR_X0 sll, R(7), 0x00000001, 0x00000001
    TEST_END
