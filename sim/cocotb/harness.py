"""Runs one program on cpu_top against memory_model.Bram.

The memory port, the end of program detection and the result check are separate pieces, so each can be replaced alone when the CPU interface changes. Only EndDetector looks at anything the current FSM decides, and only when the DUT has no halted port.

Timing, with R a rising edge of clk and F the falling edge after it. The CPU drives dmem_* from registers, so the values seen at F are the values bram0 samples at the next R. MemoryPort.step() runs at every F: it first drives dmem_rdata with the doutb computed at the previous F, then samples the port and computes the doutb that bram0 produces at the next R.

    F0   sample request q0, compute doutb(q0)
    R1   bram0 sees q0 (modelled at F0)
    F1   drive doutb(q0), sample q1
    R2   CPU captures doutb(q0)          read latency 1, as in bram0

With latency 2 the Bram adds one output register, so doutb(q0) reaches the CPU at R3.
"""

import json
import os
import struct

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge

from memory_model import SIZE, Bram, MemoryAccessError

PROGRAM_DIR = os.environ.get("PROGRAM_DIR", os.path.join(os.path.dirname(os.path.abspath(__file__)), "build"))
MEM_LATENCY = int(os.environ.get("MEM_LATENCY", "1"))
MAX_CYCLES = int(os.environ.get("MAX_CYCLES", "10000"))
RESET_CYCLES = 4
JAL_SELF = 0x0000006F  # jal x0, 0
TOHOST = 0x1FFC


def load_elf(path):
    """Returns the entry point, the PT_LOAD segments as (address, bytes) and the expected words of the section .expect as {address: value}."""
    with open(path, "rb") as f:
        elf = f.read()
    if elf[:4] != b"\x7fELF" or elf[4] != 1 or elf[5] != 1 or struct.unpack_from("<H", elf, 18)[0] != 0xF3:
        raise ValueError(f"{path} is not a 32-bit little-endian RISC-V ELF")
    entry, phoff, shoff = struct.unpack_from("<III", elf, 24)
    phentsize, phnum, shentsize, shnum, shstrndx = struct.unpack_from("<HHHHH", elf, 42)
    segments = []
    for i in range(phnum):
        p_type, p_offset, _, p_paddr, p_filesz, _ = struct.unpack_from("<6I", elf, phoff + i * phentsize)
        if p_type == 1 and p_filesz:
            segments.append((p_paddr, elf[p_offset:p_offset + p_filesz]))
    sections = [struct.unpack_from("<10I", elf, shoff + i * shentsize) for i in range(shnum)]
    names = sections[shstrndx][4]
    expect = {}
    for sh in sections:
        if elf[names + sh[0]:].split(b"\0", 1)[0] == b".expect":
            pairs = struct.unpack_from(f"<{sh[5] // 4}I", elf, sh[4])
            for addr, value in zip(pairs[0::2], pairs[1::2]):
                if addr in expect:
                    raise ValueError(f"{path}: .expect lists 0x{addr:x} twice")
                expect[addr] = value
    return entry, segments, expect


class MemoryPort:
    """Connects a Bram to the dmem_* port of the DUT, reading the port widths from the DUT."""

    def __init__(self, dut, mem):
        self.dut = dut
        self.mem = mem
        self.we_bits = len(dut.dmem_we)
        if self.we_bits not in (1, 4):
            raise MemoryAccessError(f"dmem_we has {self.we_bits} bits; expected 1 or 4")
        self.pending = 0
        dut.dmem_rdata.value = 0
        bits = len(dut.dmem_addr)
        reach = min(1 << bits, SIZE)
        dut._log.info("dmem_addr has %d bits, so the CPU reaches 0x0000-0x%04x of the modelled 0x0000-0x%04x; dmem_we has %d bit(s); read latency %d", bits, reach - 1, SIZE - 1, self.we_bits, len(mem.out))

    def step(self):
        d = self.dut
        d.dmem_rdata.value = self.pending
        values = (d.dmem_en.value, d.dmem_we.value, d.dmem_addr.value, d.dmem_wdata.value)
        if not all(v.is_resolvable for v in values):
            raise MemoryAccessError("unresolved value on the memory port: en=%s we=%s addr=%s wdata=%s" % values)
        en, we, addr, wdata = (int(v) for v in values)
        # A 1-bit dmem_we is taken as a write of all four lanes, which is what the CPU means by it. Whether the block design's 1-bit net into web[3:0] does the same on hardware is unconfirmed.
        mask = (0xF if we else 0) if self.we_bits == 1 else we
        self.pending = self.mem.clock(en, addr, wdata, mask)


class EndDetector:
    """Decides when a program has ended: through halted and trap when the DUT has them, otherwise through jal x0, 0 executed twice in a row at the same address."""

    def __init__(self, dut, mem):
        self.dut = dut
        self.mem = mem
        self.halt_port = hasattr(dut, "halted")
        self.prev_led = None
        self.last = None
        self.first_cycle = None

    def step(self, cycle):
        d = self.dut
        if self.halt_port:
            halted, trap = d.halted.value, d.trap.value
            if not (halted.is_resolvable and trap.is_resolvable):
                raise AssertionError(f"unresolved halted={halted} trap={trap}")
            if int(halted):
                self.first_cycle = cycle
                return "trap" if int(trap) else "clean"
            return None
        # The current core has no instruction boundary on its ports except led: the FSM shows 4'b0010 for exactly one cycle per instruction, while dmem_addr still holds that instruction's PC. This is the testbed's only dependence on the FSM.
        led = int(d.led.value)
        decoded = led == 0b0010 and self.prev_led != 0b0010
        self.prev_led = led
        if not decoded:
            return None
        pc = int(d.dmem_addr.value)
        here = (pc, self.mem.word(pc))
        if here[1] == JAL_SELF and here == self.last:
            d._log.info("jal x0, 0 at 0x%04x decoded at cycle %d and again at cycle %d", pc, self.first_cycle, cycle)
            return "clean"
        if here != self.last:
            self.first_cycle = cycle
        self.last = here
        return None


async def start_clock(dut):
    """Starts the clock with reset asserted and waits for the first rising edge, so every register of the CPU holds its reset value."""
    dut.rst_n.value = 0
    dut.dmem_rdata.value = 0
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await RisingEdge(dut.clk)


def program_path(name):
    return os.path.join(PROGRAM_DIR, name + ".elf")


def load(dut, name, latency=None):
    """Builds a zeroed Bram holding the program image at its linked addresses. Bram.load refuses bytes outside 0x0000-0x1fff."""
    entry, segments, _ = load_elf(program_path(name))
    if entry != 0:
        raise ValueError(f"{name}: entry point 0x{entry:x}, but the CPU starts at 0x0")
    mem = Bram(latency or MEM_LATENCY)
    for addr, blob in segments:
        mem.load(addr, blob)
    return mem, bytes(mem.data), MemoryPort(dut, mem)


async def reset(dut, port):
    """Holds rst_n low for RESET_CYCLES rising edges and releases it at a falling edge. Cycle 1 is the first rising edge with rst_n high."""
    dut.rst_n.value = 0
    for _ in range(RESET_CYCLES):
        await FallingEdge(dut.clk)
        port.step()
    dut.rst_n.value = 1


async def run(dut, port, end, max_cycles):
    """Returns the outcome, one of clean, trap or timeout, and the cycle count since reset release."""
    for cycle in range(1, max_cycles + 1):
        await FallingEdge(dut.clk)
        port.step()
        outcome = end.step(cycle)
        if outcome:
            return outcome, cycle
    return "timeout", max_cycles


def check_memory(mem, image, expected):
    """Compares all 8 KiB with the program image overlaid by the expected words, so a store to a wrong address fails too."""
    want = bytearray(image)
    for addr, value in expected.items():
        want[addr:addr + 4] = value.to_bytes(4, "little")
    bad = [f"0x{a:04x}: expected 0x{int.from_bytes(want[a:a + 4], 'little'):08x}, got 0x{mem.word(a):08x}" for a in range(0, SIZE, 4) if mem.data[a:a + 4] != want[a:a + 4]]
    assert not bad, "memory differs from the expected image:\n" + "\n".join(bad)


async def execute(dut, name, expected=None, outcome="clean", latency=None, max_cycles=None):
    """Loads, resets and runs one program, checks how it ended and checks the whole memory. expected defaults to the program's .expect section. Returns the cycle count."""
    _, segments, expect = load_elf(program_path(name))
    expected = expect if expected is None else expected
    for addr in expected:
        for base, blob in segments:
            assert not base - 4 < addr < base + len(blob), f"{name}: expected word 0x{addr:04x} lies inside the program image"
    mem, image, port = load(dut, name, latency)
    await reset(dut, port)
    end = EndDetector(dut, mem)
    got, cycles = await run(dut, port, end, max_cycles or MAX_CYCLES)
    assert got == outcome, f"{name}: expected {outcome}, got {got} after {cycles} cycles"
    dut._log.info("%s: %s, end reached at cycle %d, detected at cycle %d after reset release", name, got, end.first_cycle, cycles)
    check_memory(mem, image, expected)
    return end.first_cycle


def write_manifest(namespace, blocked=None):
    """Records every cocotb test in a module, and why each blocked one cannot run, in the file MANIFEST names, for check_results.py."""
    path = os.environ.get("MANIFEST")
    if path:
        tests = [o.__name__ for o in namespace.values() if isinstance(o, cocotb.test)]
        with open(path, "w") as f:
            json.dump({"tests": tests, "blocked": blocked or {}}, f, indent=1)
