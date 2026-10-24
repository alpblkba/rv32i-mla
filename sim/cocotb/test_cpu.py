"""Directed tests of cpu_top. Each test runs the program of the same name from sw/tests/asm/ and checks the whole memory against hand-written words; every word not listed must keep its value from the program image."""

import cocotb
from cocotb.triggers import FallingEdge

from harness import MAX_CYCLES, EndDetector, check_memory, execute, load, reset, run, start_clock, write_manifest

FULLWORD = {0x100: 0x12345678, 0x104: 0x12345678, 0x108: 0xEDCBA988}


@cocotb.test()
async def smoke(dut):
    await start_clock(dut)
    await execute(dut, "smoke", {0x100: 0x0000000C})


@cocotb.test()
async def no_branch(dut):
    await start_clock(dut)
    await execute(dut, "no_branch", {0x100: 0x0000000C, 0x104: 0x00000002})


@cocotb.test()
async def branch_only(dut):
    """0x108 holds the word lw put in x4. With a wrong load, beq falls through and 0x104 holds 1."""
    await start_clock(dut)
    await execute(dut, "branch_only", {0x100: 0x0000000C, 0x104: 0x00000002, 0x108: 0x0000000C})


@cocotb.test()
async def jump_only(dut):
    """0x108 must stay 0, since the store before pass is skipped. 0x10c holds the link value of jal x6 at 0x14."""
    await start_clock(dut)
    await execute(dut, "jump_only", {0x100: 0x0000000C, 0x104: 0x00000002, 0x10C: 0x00000018})


@cocotb.test()
async def fullword(dut):
    await start_clock(dut)
    await execute(dut, "fullword", FULLWORD)


@cocotb.test()
async def alu(dut):
    await start_clock(dut)
    await execute(dut, "alu", {
        0x100: 0x000007FF, 0x104: 0xFFFFF800, 0x108: 0xFFFFFFFF, 0x10C: 0xFFFFF001,
        0x110: 0x00000FFF, 0x114: 0x00000004, 0x118: 0xFFFFFFFE, 0x11C: 0xFFFFF801,
        0x120: 0x00000030, 0x124: 0x000000FC, 0x128: 0x00000001, 0x12C: 0xFFFFFFFF,
        0x130: 0x00000077, 0x134: 0x000007FF,
    })


@cocotb.test()
async def wrap(dut):
    await start_clock(dut)
    await execute(dut, "wrap", {
        0x100: 0x80000000, 0x104: 0x7FFFFFFF, 0x108: 0x80000000,
        0x10C: 0x00000003, 0x110: 0x80000000, 0x114: 0x00000001,
    })


@cocotb.test()
async def control(dut):
    await start_clock(dut)
    await execute(dut, "control", {
        0x100: 0x0000000F, 0x104: 0x00000002, 0x108: 0x00000021, 0x10C: 0x00000032,
        0x110: 0x00000033, 0x114: 0x00000044, 0x118: 0x00000065, 0x11C: 0x00000066,
        0x120: 0x00000077,
    })


@cocotb.test()
async def reset_rerun(dut):
    """Runs fullword after a reset, again after a second reset with a fresh image, and once more with a reset halfway through a run, without reloading memory."""
    await start_clock(dut)
    first = await execute(dut, "fullword", FULLWORD)
    second = await execute(dut, "fullword", FULLWORD)
    mem, image, port = load(dut, "fullword")
    await reset(dut, port)
    for _ in range(first // 2):
        await FallingEdge(dut.clk)
        port.step()
    await reset(dut, port)
    end = EndDetector(dut, mem)
    outcome, cycles = await run(dut, port, end, MAX_CYCLES)
    dut._log.info("fullword after a mid-run reset: %s at cycle %s; earlier runs ended at cycles %d and %d", outcome, end.first_cycle, first, second)
    assert outcome == "clean", f"after a mid-run reset: {outcome} after {cycles} cycles"
    check_memory(mem, image, FULLWORD)


write_manifest(globals())
