#include "isa.h"
// SRA: arithmetic right shift copies bit 31, so negative values give a different result from SRL.
.section .text
.globl _start
_start:
    TEST_RR    sra, R(0), 0x80000000, 0x00000001, 0xc0000000
    TEST_RR    sra, R(1), 0x80000000, 0x0000001f, 0xffffffff
    TEST_RR    sra, R(2), 0x7fffffff, 0x00000004, 0x07ffffff
    TEST_RR    sra, R(3), 0xf0000000, 0xffffffe4, 0xff000000
    TEST_RR    sra, R(4), 0x87654321, 0x00000000, 0x87654321
    TEST_RR_D1 sra, R(5), 0xffffff00, 0x00000004, 0xfffffff0
    TEST_RR_X0 sra, R(6), 0x80000000, 0x00000001
    TEST_END
