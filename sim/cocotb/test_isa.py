"""Full RV32I acceptance suite: the directed programs isa_*.S and trap_*.S and the vendored rv32ui tests, one cocotb test per row of coverage.csv.

A directed test checks the whole memory against the words in its .expect section and must end clean, or with a trap for trap_*. An rv32ui test must end clean with tohost reading 1. A test whose program needs a port this DUT does not have, or an address beyond what its dmem_addr can express, is registered as skipped together with the reason, and check_results.py reports it as BLOCKED. RUN_BLOCKED=1 runs such tests anyway, for diagnosis only.
"""

import csv
import glob
import os

import cocotb

from harness import SIZE, TOHOST, EndDetector, execute, load, load_elf, program_path, reset, run, start_clock, write_manifest

HERE = os.path.dirname(os.path.abspath(__file__))
ASM_DIR = os.path.join(HERE, "..", "..", "sw", "tests", "asm")
RV32UI_DIR = os.path.join(HERE, "..", "..", "sw", "tests", "riscv-tests", "isa", "rv32ui")
UPSTREAM_CYCLES = int(os.environ.get("MAX_CYCLES", "100000"))

top = cocotb.top
ADDR_BITS = len(top.dmem_addr)
WE_BITS = len(top.dmem_we)
HAS_HALT = hasattr(top, "halted") and hasattr(top, "trap")
REACH = min(1 << ADDR_BITS, SIZE)
RUN_BLOCKED = os.environ.get("RUN_BLOCKED") == "1"

with open(os.path.join(HERE, "coverage.csv")) as f:
    NEEDS = {row["test"]: row["needs"] for row in csv.DictReader(f)}

on_disk = {os.path.basename(p)[:-2] for p in glob.glob(os.path.join(ASM_DIR, "isa_*.S")) + glob.glob(os.path.join(ASM_DIR, "trap_*.S"))}
on_disk |= {"rv32ui_" + os.path.basename(p)[:-2] for p in glob.glob(os.path.join(RV32UI_DIR, "*.S"))}
if on_disk != set(NEEDS):
    raise RuntimeError(f"coverage.csv and the test programs disagree: only in coverage.csv {sorted(set(NEEDS) - on_disk)}, only on disk {sorted(on_disk - set(NEEDS))}")


def blocked_reason(name):
    why = []
    if "halt" in NEEDS[name] and not HAS_HALT:
        why.append("needs the halted and trap outputs, which this DUT does not have")
    if "we4" in NEEDS[name] and WE_BITS != 4:
        why.append(f"needs a 4-bit dmem_we, and this DUT has {WE_BITS} bit")
    _, segments, expect = load_elf(program_path(name))
    end = max([a + len(b) for a, b in segments] + [a + 4 for a in expect])
    if end > REACH:
        why.append(f"uses addresses up to 0x{end - 1:04x}, beyond 0x{REACH - 1:04x}, which is all a {ADDR_BITS}-bit dmem_addr reaches")
    return "; ".join(why)


async def directed(dut, name):
    await start_clock(dut)
    await execute(dut, name, outcome="trap" if name.startswith("trap_") else "clean")


async def upstream(dut, name):
    await start_clock(dut)
    mem, _, port = load(dut, name)
    await reset(dut, port)
    end = EndDetector(dut, mem)
    got, cycles = await run(dut, port, end, UPSTREAM_CYCLES)
    tohost = mem.word(TOHOST)
    last = "no store" if not mem.writes else "last store 0x%08x at 0x%04x" % mem.writes[-1][1::-1]
    assert got == "clean", f"{name}: expected clean, got {got} after {cycles} cycles, tohost 0x{tohost:08x}, {last}"
    assert tohost == 1, f"{name}: tohost is 0x{tohost:08x}, " + ("never written" if tohost == 0 else f"so test case {tohost >> 1} failed") + f", {last}"
    dut._log.info("%s: tohost 1, end reached at cycle %d", name, end.first_cycle)


BLOCKED = {}
for _name in NEEDS:
    _reason = blocked_reason(_name)
    if _reason:
        BLOCKED[_name] = _reason
        top._log.info("BLOCKED %s: %s", _name, _reason)
    _body = upstream if _name.startswith("rv32ui_") else directed

    async def _test(dut, name=_name, body=_body):
        await body(dut, name)

    _test.__name__ = _test.__qualname__ = _name
    globals()[_name] = cocotb.test(skip=bool(_reason) and not RUN_BLOCKED)(_test)

write_manifest(globals(), BLOCKED)
