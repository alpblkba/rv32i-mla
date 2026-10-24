#include "isa.h"
// LW: full words with bit 31 set and clear, and a load through a base register with a negative offset.
.section .text
.globl _start
_start:
    TEST_LD  lw, R(0), 0x89abcdef, 0, 0x89abcdef
    TEST_LD  lw, R(1), 0x01234567, 0, 0x01234567
    TEST_LDB lw, R(2), 0xfedcba98, 0, 0xfedcba98
    TEST_END
