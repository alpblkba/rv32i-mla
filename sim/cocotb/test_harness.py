"""Tests of the harness on stub_cpu.v, which has the planned port: 32-bit dmem_addr, 4-bit dmem_we and sticky halted and trap. They cover what the current cpu_top cannot reach: byte lanes, addresses at or above 0x2000, the halt and trap outcomes and the timeout, plus the read latency measured end to end."""

import cocotb
from cocotb.triggers import FallingEdge, RisingEdge

from harness import EndDetector, MemoryPort, reset, run, start_clock, write_manifest
from memory_model import Bram, MemoryAccessError


async def setup(dut, latency=1):
    for name in ("t_en", "t_we", "t_addr", "t_wdata", "t_halt", "t_trap"):
        getattr(dut, name).value = 0
    await start_clock(dut)
    mem = Bram(latency)
    mem.load(0x100, (0x11111111).to_bytes(4, "little") + (0x22222222).to_bytes(4, "little"))
    port = MemoryPort(dut, mem)
    await reset(dut, port)
    return mem, port


async def latency(dut, cycles):
    """Puts address 0x100 on the port after a run at 0x104 and returns how many rising edges pass until the stub captures the word at 0x100."""
    mem, port = await setup(dut, cycles)
    dut.t_en.value = 1
    dut.t_addr.value = 0x104
    for _ in range(4):
        await FallingEdge(dut.clk)
        port.step()
    dut.t_addr.value = 0x100
    seen = None
    for edge in range(1, 8):
        await FallingEdge(dut.clk)
        port.step()
        # Both values are read at a falling edge, half a cycle after the rising edge that changed them.
        if seen is None and int(dut.dmem_addr.value) == 0x100:
            seen = edge
        if seen is not None and int(dut.q_rdata.value) == 0x11111111:
            return edge - seen
    raise AssertionError("the word at 0x100 never reached the stub")


@cocotb.test()
async def read_latency_1(dut):
    """bram0 has one cycle of read latency: a CPU that changes dmem_addr at one rising edge captures the data at the second rising edge after it."""
    assert await latency(dut, 1) == 2


@cocotb.test()
async def read_latency_2(dut):
    assert await latency(dut, 2) == 3


async def write(dut, port, addr, data, we):
    dut.t_en.value = 1
    dut.t_addr.value = addr
    dut.t_wdata.value = data
    dut.t_we.value = we
    await FallingEdge(dut.clk)
    port.step()
    dut.t_we.value = 0
    for _ in range(3):
        await FallingEdge(dut.clk)
        port.step()


@cocotb.test()
async def byte_lanes(dut):
    """With a 4-bit dmem_we, each bit writes one lane and the other lanes keep their bytes."""
    mem, port = await setup(dut)
    await write(dut, port, 0x200, 0xA1B2C3D4, 0b1111)
    await write(dut, port, 0x200, 0x55667788, 0b0100)
    assert mem.word(0x200) == 0xA166C3D4, hex(mem.word(0x200))
    await write(dut, port, 0x203, 0x99000000, 0b1000)
    assert mem.word(0x200) == 0x9966C3D4, hex(mem.word(0x200))
    await write(dut, port, 0x200, 0x00000000, 0b0000)
    assert mem.word(0x200) == 0x9966C3D4, hex(mem.word(0x200))


@cocotb.test()
async def address_0x2000_fails(dut):
    """With a 32-bit dmem_addr the CPU can leave the 8 KiB, and any enabled access there must fail the test; a disabled port may hold any address."""
    mem, port = await setup(dut)
    dut.t_addr.value = 0x2000
    dut.t_en.value = 0
    for _ in range(3):
        await FallingEdge(dut.clk)
        port.step()
    dut.t_en.value = 1
    for _ in range(2):
        await FallingEdge(dut.clk)
        try:
            port.step()
        except MemoryAccessError as e:
            dut._log.info("refused as expected: %s", e)
            return
    raise AssertionError("an enabled access at 0x2000 was accepted")


async def halt_after(dut, cycles, trap):
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    dut.t_halt.value = 1
    dut.t_trap.value = trap
    await FallingEdge(dut.clk)
    dut.t_halt.value = 0
    dut.t_trap.value = 0


@cocotb.test()
async def halt_clean(dut):
    mem, port = await setup(dut)
    cocotb.start_soon(halt_after(dut, 5, 0))
    outcome, cycles = await run(dut, port, EndDetector(dut, mem), 50)
    assert outcome == "clean", outcome
    assert int(dut.halted.value) == 1 and int(dut.trap.value) == 0


@cocotb.test()
async def halt_trap(dut):
    mem, port = await setup(dut)
    cocotb.start_soon(halt_after(dut, 5, 1))
    outcome, cycles = await run(dut, port, EndDetector(dut, mem), 50)
    assert outcome == "trap", outcome
    for _ in range(3):
        await RisingEdge(dut.clk)
    assert int(dut.halted.value) == 1 and int(dut.trap.value) == 1, "halted and trap must stay high until reset"


@cocotb.test()
async def timeout_without_halt(dut):
    mem, port = await setup(dut)
    outcome, cycles = await run(dut, port, EndDetector(dut, mem), 50)
    assert (outcome, cycles) == ("timeout", 50), (outcome, cycles)


write_manifest(globals())
