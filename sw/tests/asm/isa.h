// Macros for the directed tests isa_*.S and trap_*.S.
// A test writes each result with sw to a word R(n) in 0x400-0x7fc and records the word it expects there in the section .expect. That section is not loaded into memory, so the CPU cannot see or change it; the harness reads it from the ELF and compares all 8 KiB with the program image overlaid by these words.
// Operands come from .rodata words read with lw, so a test needs only the ten implemented instructions besides the one under test. Code and data stay below 0x400, which keeps every address reachable from x0 with a 12-bit offset on the current 11-bit port as well.
// The destination is loaded with the expected value inverted before the instruction under test runs, so an instruction that does nothing cannot leave the right result.

#define R(n) (0x400 + 4 * (n))
#define SENTINEL 0xa5a5a5a5
#define TOHOST 0x1ffc

.macro EXPECT addr, value
    .pushsection .expect, "", @progbits
    .word \addr, \value
    .popsection
.endm

.macro CHECK reg, addr, value
    sw   \reg, \addr(x0)
    EXPECT \addr, \value
.endm

// Halts the planned core cleanly; on the current core ecall does nothing and the jal x0, 0 loop ends the run.
.macro TEST_END
    ecall
999: jal x0, 999b
.endm

// Writes 1 to tohost, building 0x1ffc as 0x7ff * 4. A trap test runs this only when the instruction before it failed to trap.
.macro TOHOST_FAIL
    addi x30, x0, 0x7ff
    add  x30, x30, x30
    add  x30, x30, x30
    addi x31, x0, 1
    sw   x31, 0(x30)
.endm

// rd = x3 from rs1 = x1 and rs2 = x2.
.macro TEST_RR op, addr, a, b, want
    .pushsection .rodata
    .balign 4
99: .word \a, \b, (\want) ^ 0xffffffff
    .popsection
    lw   x1, %lo(99b)(x0)
    lw   x2, %lo(99b + 4)(x0)
    lw   x3, %lo(99b + 8)(x0)
    \op  x3, x1, x2
    CHECK x3, \addr, \want
.endm

// rd is the same register as rs1, so the result must be written after both sources are read.
.macro TEST_RR_D1 op, addr, a, b, want
    .pushsection .rodata
    .balign 4
99: .word \a, \b
    .popsection
    lw   x1, %lo(99b)(x0)
    lw   x2, %lo(99b + 4)(x0)
    \op  x1, x1, x2
    CHECK x1, \addr, \want
.endm

// rd is x0, which must read as 0 afterwards.
.macro TEST_RR_X0 op, addr, a, b
    .pushsection .rodata
    .balign 4
99: .word \a, \b
    .popsection
    lw   x1, %lo(99b)(x0)
    lw   x2, %lo(99b + 4)(x0)
    \op  x0, x1, x2
    CHECK x0, \addr, 0
.endm

// rd = x3 from rs1 = x1 and the 12-bit immediate imm, written as the assembler takes it.
.macro TEST_RI op, addr, a, imm, want
    .pushsection .rodata
    .balign 4
99: .word \a, (\want) ^ 0xffffffff
    .popsection
    lw   x1, %lo(99b)(x0)
    lw   x3, %lo(99b + 4)(x0)
    \op  x3, x1, \imm
    CHECK x3, \addr, \want
.endm

.macro TEST_RI_D1 op, addr, a, imm, want
    .pushsection .rodata
    .balign 4
99: .word \a
    .popsection
    lw   x1, %lo(99b)(x0)
    \op  x1, x1, \imm
    CHECK x1, \addr, \want
.endm

.macro TEST_RI_X0 op, addr, a, imm
    .pushsection .rodata
    .balign 4
99: .word \a
    .popsection
    lw   x1, %lo(99b)(x0)
    \op  x0, x1, \imm
    CHECK x0, \addr, 0
.endm

.macro TEST_LUI addr, imm, want
    .pushsection .rodata
    .balign 4
99: .word (\want) ^ 0xffffffff
    .popsection
    lw   x3, %lo(99b)(x0)
    lui  x3, \imm
    CHECK x3, \addr, \want
.endm

// x3 = the load of width op from word + off, addressed from x0.
.macro TEST_LD op, addr, word, off, want
    .pushsection .rodata
    .balign 4
99: .word \word, (\want) ^ 0xffffffff
    .popsection
    lw   x3, %lo(99b + 4)(x0)
    \op  x3, %lo(99b + \off)(x0)
    CHECK x3, \addr, \want
.endm

// The same load through a base register and a negative offset, with the result written over the base register.
.macro TEST_LDB op, addr, word, off, want
    .pushsection .rodata
    .balign 4
99: .word \word
    .popsection
    addi x1, x0, %lo(99b + \off + 16)
    \op  x1, -16(x1)
    CHECK x1, \addr, \want
.endm

// The word at addr starts as init, then the store of width op writes data at addr + off.
.macro TEST_ST op, addr, init, data, off, want
    .pushsection .rodata
    .balign 4
99: .word \init, \data
    .popsection
    lw   x1, %lo(99b)(x0)
    sw   x1, \addr(x0)
    lw   x2, %lo(99b + 4)(x0)
    \op  x2, (\addr + \off)(x0)
    EXPECT \addr, \want
.endm

.macro TEST_STB op, addr, init, data, off, want
    .pushsection .rodata
    .balign 4
99: .word \init, \data
    .popsection
    lw   x1, %lo(99b)(x0)
    sw   x1, \addr(x0)
    lw   x2, %lo(99b + 4)(x0)
    addi x4, x0, \addr + \off + 16
    \op  x2, -16(x4)
    EXPECT \addr, \want
.endm

// The word at addr ends as 2 if the branch is taken and 1 if it falls through. taken is 1 or 0.
.macro TEST_BR op, addr, a, b, taken
    .pushsection .rodata
    .balign 4
99: .word \a, \b
    .popsection
    lw   x1, %lo(99b)(x0)
    lw   x2, %lo(99b + 4)(x0)
    addi x3, x0, 1
    \op  x1, x2, 98f
    sw   x3, \addr(x0)
    jal  x0, 97f
98: addi x3, x0, 2
    sw   x3, \addr(x0)
97:
    EXPECT \addr, 1 + \taken
.endm

// The same with the target before the branch, so the offset is negative.
.macro TEST_BRB op, addr, a, b, taken
    .pushsection .rodata
    .balign 4
99: .word \a, \b
    .popsection
    lw   x1, %lo(99b)(x0)
    lw   x2, %lo(99b + 4)(x0)
    addi x3, x0, 1
    jal  x0, 96f
98: addi x3, x0, 2
    sw   x3, \addr(x0)
    jal  x0, 97f
96: \op  x1, x2, 98b
    sw   x3, \addr(x0)
97:
    EXPECT \addr, 1 + \taken
.endm

// A branch that must not be taken, with a target that is not 4-byte aligned. Only a taken branch may trap on its target.
.macro TEST_BR_NT_ODD op, addr, a, b
    .pushsection .rodata
    .balign 4
99: .word \a, \b
    .popsection
    lw   x1, %lo(99b)(x0)
    lw   x2, %lo(99b + 4)(x0)
    addi x3, x0, 3
    \op  x1, x2, . + 6
    CHECK x3, \addr, 3
.endm
