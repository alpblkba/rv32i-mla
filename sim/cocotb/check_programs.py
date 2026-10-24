"""Checks the directed test programs before any simulation. Usage: check_programs.py ASM_DIR BUILD_DIR.

Every TEST_* line in isa_*.S carries its expected word written by hand. This script recomputes that word from the operands with one small reference function per instruction, so a wrong hand calculation fails here instead of failing later against a correct CPU. The two values come from different methods, hand arithmetic and Python, which is the only independence they have: both were written from the RISC-V specification by the same author.

It also checks that each program would fail on the defaults of the current core, where an unsupported OP or OP-IMM writes 0, OP with funct3 000 runs as ADD, an unsupported load or store does nothing and an unsupported branch falls through. Then it reads the disassembly in BUILD_DIR: every isa_<op> program must contain op at least once per case, and every trap_*.S program must contain the encoding named in its comment.
"""

import glob
import operator
import os
import re
import sys

M = 0xFFFFFFFF


def sg(x):
    return x - (1 << 32) if x & 0x80000000 else x


def sx(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v


RR = {
    "add": operator.add, "sub": operator.sub, "xor": operator.xor, "or": operator.or_, "and": operator.and_,
    "sll": lambda a, b: a << (b & 31), "srl": lambda a, b: a >> (b & 31), "sra": lambda a, b: sg(a) >> (b & 31),
    "slt": lambda a, b: sg(a) < sg(b), "sltu": lambda a, b: a < b,
}
RI = {
    "addi": lambda a, i: a + sx(i, 12), "xori": lambda a, i: a ^ (sx(i, 12) & M), "ori": lambda a, i: a | (sx(i, 12) & M),
    "andi": lambda a, i: a & (sx(i, 12) & M), "slti": lambda a, i: sg(a) < sx(i, 12), "sltiu": lambda a, i: a < (sx(i, 12) & M),
    "slli": lambda a, i: a << i, "srli": lambda a, i: a >> i, "srai": lambda a, i: sg(a) >> i,
}
LD = {
    "lb": lambda w, o: sx(w >> 8 * o, 8), "lbu": lambda w, o: w >> 8 * o & 0xFF,
    "lh": lambda w, o: sx(w >> 8 * o, 16), "lhu": lambda w, o: w >> 8 * o & 0xFFFF, "lw": lambda w, o: w,
}
WIDTH = {"sb": 0xFF, "sh": 0xFFFF, "sw": M}
BR = {
    "beq": lambda a, b: a == b, "bne": lambda a, b: a != b, "blt": lambda a, b: sg(a) < sg(b),
    "bge": lambda a, b: sg(a) >= sg(b), "bltu": lambda a, b: a < b, "bgeu": lambda a, b: a >= b,
}

errors = []


def fail(where, msg):
    errors.append(f"{where}: {msg}")


def check_source(path):
    """Returns the instruction under test and the number of cases, after checking every expected word."""
    op_under_test = os.path.basename(path)[4:-2]
    cases = []  # (macro, op, operands, want)
    for n, line in enumerate(open(path), 1):
        m = re.match(r"\s*(TEST_\w+)[ \t]+(.*?)\s*(#.*)?$", line)
        if not m or m.group(1) == "TEST_END":
            continue
        where = f"{path}:{n}"
        args = [a.strip() for a in m.group(2).split(",")]
        macro = m.group(1)
        num = [int(a, 0) for a in args[2:]] if macro != "TEST_LUI" else [int(a, 0) for a in args[1:]]
        op = args[0] if macro != "TEST_LUI" else "lui"
        if op != op_under_test:
            fail(where, f"{macro} tests {op}, but the file tests {op_under_test}")
        if macro in ("TEST_RR", "TEST_RR_D1"):
            a, b, want = num
            got = RR[op](a, b) & M
        elif macro in ("TEST_RI", "TEST_RI_D1"):
            a, imm, want = num
            limit = range(32) if op in ("slli", "srli", "srai") else range(-2048, 2048)
            if imm not in limit:
                fail(where, f"immediate {imm} outside {limit}")
            got = RI[op](a, imm) & M
        elif macro == "TEST_LUI":
            imm, want = num
            got = imm << 12 & M
        elif macro in ("TEST_LD", "TEST_LDB"):
            word, off, want = num
            got = LD[op](word, off) & M
        elif macro in ("TEST_ST", "TEST_STB"):
            init, data, off, want = num
            mask = WIDTH[op] << 8 * off
            got = (init & ~mask | (data << 8 * off) & mask) & M
        elif macro in ("TEST_BR", "TEST_BRB"):
            a, b, taken = num
            want = 1 + taken
            got = 1 + int(BR[op](a, b))
        elif macro == "TEST_BR_NT_ODD":
            a, b = num
            want, got = 0, int(BR[op](a, b))
        elif macro in ("TEST_RR_X0", "TEST_RI_X0"):
            continue
        else:
            fail(where, f"unknown macro {macro}")
            continue
        if got != want:
            fail(where, f"expected 0x{want:08x} written by hand, the reference gives 0x{got:08x}")
        cases.append((macro, op, num, want))
    defaults(path, op_under_test, cases)
    return op_under_test, len(cases)


def defaults(path, op, cases):
    """Fails when no case of the file would catch one of the current core's wrong defaults."""
    if not cases:
        return
    wants = [c[3] for c in cases]
    if op in RR or op in RI or op == "lui":
        if all(w == 0 for w in wants):
            fail(path, "every expected result is 0, so a core that writes 0 passes")
        if op not in ("add", "addi", "lui") and all(w == (c[2][0] + c[2][1]) & M for c, w in zip(cases, wants)):
            fail(path, "every expected result equals the ADD of the operands")
    if op in LD and op != "lw" and all(c[3] == c[2][0] for c in cases):
        fail(path, "every expected result equals the full word, so LW passes")
    if op in WIDTH:
        if all(c[3] == c[2][0] for c in cases):
            fail(path, "every expected word equals its initial value, so a store that does nothing passes")
        if op != "sw" and all(c[3] == c[2][1] for c in cases):
            fail(path, "every expected word equals the store data, so SW passes")
    if op in BR:
        taken = [c[2][2] for c in cases if c[0] in ("TEST_BR", "TEST_BRB")]
        if 1 not in taken or 0 not in taken:
            fail(path, "needs both a taken and a not taken case")


def disassembly(build, name):
    path = os.path.join(build, name + ".dump")
    lines = []
    for line in open(path):
        m = re.match(r"\s*[0-9a-f]+:\s+([0-9a-f]{8})\s+(\S+)", line)
        if m:
            lines.append((int(m.group(1), 16), m.group(2)))
    return lines


def main(asm, build):
    for path in sorted(glob.glob(os.path.join(asm, "isa_*.S"))):
        op, n = check_source(path)
        found = sum(1 for _, mnem in disassembly(build, os.path.basename(path)[:-2]) if mnem == op)
        if found < max(n, 1):
            fail(path, f"the disassembly holds {found} {op} instructions for {n} cases")
    for path in sorted(glob.glob(os.path.join(asm, "trap_*.S"))):
        m = re.search(r"encoding: (0x[0-9a-f]{8})", open(path).read())
        if not m:
            fail(path, "no encoding comment")
            continue
        word = int(m.group(1), 16)
        if word not in (w for w, _ in disassembly(build, os.path.basename(path)[:-2])):
            fail(path, f"the disassembly does not contain {m.group(1)}")
    for e in errors:
        print(f"error: {e}", file=sys.stderr)
    print(f"check_programs: {len(glob.glob(os.path.join(asm, 'isa_*.S')))} isa and {len(glob.glob(os.path.join(asm, 'trap_*.S')))} trap programs, {len(errors)} errors")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
