// Local replacement for the riscv-tests env/p/riscv_test.h, as the contract requires: no CSR, no trap vector, and the result in the word tohost at 0x1ffc.
// tohost is written as 1 on pass and as (TESTNUM << 1) | 1 on fail, and both paths end with ecall followed by jal x0, 0, so a test stops on the current core and on the core with halted.
// The pass and fail code uses only addi, add, beq, sw, ecall and jal, all but ecall present in the current core, so that a broken LUI or AUIPC cannot misreport the result.

#ifndef RV32I_MLA_RISCV_TEST_H
#define RV32I_MLA_RISCV_TEST_H

#define RVTEST_RV32U .macro init; .endm
#define RVTEST_RV64U RVTEST_RV32U

#define TESTNUM gp

#define RVTEST_CODE_BEGIN \
        .section .text.init, "ax", @progbits; \
        .globl _start; \
_start: \
        init;

#define RVTEST_CODE_END

// 0x7ff * 4 is 0x1ffc, built without LUI.
#define RVTEST_TOHOST_WRITE \
        addi t0, x0, 0x7ff; \
        add t0, t0, t0; \
        add t0, t0, t0; \
        sw TESTNUM, 0(t0); \
        ecall; \
1:      jal x0, 1b

#define RVTEST_PASS \
        addi TESTNUM, x0, 1; \
        RVTEST_TOHOST_WRITE

// Failing with TESTNUM 0 would write 1 and read as a pass, so that case spins on a beq and ends as a timeout.
#define RVTEST_FAIL \
2:      beq TESTNUM, x0, 2b; \
        add TESTNUM, TESTNUM, TESTNUM; \
        addi TESTNUM, TESTNUM, 1; \
        RVTEST_TOHOST_WRITE

#define RVTEST_DATA_BEGIN \
        .pushsection .tohost, "aw", @progbits; \
        .balign 4; \
        .globl tohost; \
tohost: .word 0; \
        .popsection; \
        .balign 4;

#define RVTEST_DATA_END

#endif
