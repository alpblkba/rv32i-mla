#include "isa.h"
// EBREAK: the core stops with halted high and trap low, so the store after the ebreak must not run.
.section .text
.globl _start
_start:
    addi x5, x0, 0x5a
    CHECK x5, R(0), 0x5a
    ebreak
    addi x6, x0, 0x66
    sw   x6, R(1)(x0)
    TEST_END
