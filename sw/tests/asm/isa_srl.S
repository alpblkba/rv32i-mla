#include "isa.h"
// SRL: logical right shift fills with zeros, shift amounts 0, 1, 4 and 31, and only rs2[4:0] counts.
.section .text
.globl _start
_start:
    TEST_RR    srl, R(0), 0x80000000, 0x0000001f, 0x00000001
    TEST_RR    srl, R(1), 0x80000000, 0x00000001, 0x40000000
    TEST_RR    srl, R(2), 0xffffffff, 0x00000004, 0x0fffffff
    TEST_RR    srl, R(3), 0xffffffff, 0xffffffe4, 0x0fffffff
    TEST_RR    srl, R(4), 0x12345678, 0x00000000, 0x12345678
    TEST_RR    srl, R(5), 0x12345678, 0x00000020, 0x12345678
    TEST_RR_D1 srl, R(6), 0x000000f0, 0x00000004, 0x0000000f
    TEST_RR_X0 srl, R(7), 0x00000001, 0x00000001
    TEST_END
