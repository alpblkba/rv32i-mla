# Boardless testbed for cpu_top

This directory runs `RV32I-MLA.srcs/sources_1/new/cpu_top.v` in cocotb against a Python model of the `bram0` block RAM, with no Vivado and no board. It holds two suites: a baseline for the ten instructions the CPU implements today, and the full RV32I acceptance suite that the ISA work has to make pass.

## Install

You need Python 3, Icarus Verilog, GNU make and a bare-metal RISC-V GNU toolchain with the prefix `riscv64-unknown-elf-`. The testbed was verified with Python 3.11.15, Icarus Verilog 12.0, Verilator 5.020, `riscv64-unknown-elf-gcc` 13.2.0 and GNU as 2.42 on Ubuntu 24.04, where these commands install them:

```sh
sudo apt-get install iverilog verilator gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf
python3 -m venv ~/venv/cocotb
. ~/venv/cocotb/bin/activate
pip install -r sim/cocotb/requirements.txt
```

`requirements.txt` pins cocotb 1.9.2, because cocotb 2.1.0 refuses Verilator 5.020 with `cocotb requires Verilator 5.036 or later`. If your toolchain has another prefix, pass it as `RV_PREFIX=riscv32-unknown-elf-`.

## Run

`make -C sim/cocotb` builds every program and runs the baseline: the unit tests of the memory model and of `check_results.py`, the checks of `check_programs.py`, the nine CPU tests in `test_cpu.py` and the harness tests in `test_harness.py`. It must exit 0 on the current CPU. `make -C sim/cocotb isa` runs the full RV32I suite in `test_isa.py`, which exits nonzero until the CPU implements RV32I with the port the contract plans.

```sh
make -C sim/cocotb                         # baseline, the CI gate
make -C sim/cocotb isa                     # full RV32I suite
make -C sim/cocotb cpu TESTCASE=branch_only
make -C sim/cocotb isa TESTCASE=isa_sltu
make -C sim/cocotb SIM=verilator
make -C sim/cocotb isa SIM=verilator
```

The single suites are `model`, `cpu`, `harness` and `isa`. Programs build into `sim/cocotb/build/`, which git ignores, with an ELF, a disassembly and a linker map for each; the files in `sw/tests/artifacts/` are never touched. `build/coverage_<sim>.csv` is `coverage.csv` with the status of each test from the last `isa` run.

## Results

`check_results.py` gives every test one status. PASS and XFAIL are clean. FAIL, XPASS and BLOCKED make the command exit nonzero, and so does a missing or malformed results file, an empty run, a skip without a reason, a name in `known_failures.txt` that is not a test, or a registered test without a result.

PASS means the test ran and every check held. FAIL means it ran and a check failed. XFAIL means it failed and is listed in `known_failures.txt`, which holds only tests that run on the current CPU and fail because it lacks the instruction. XPASS means a listed test passed, so remove its line in the same commit as the RTL change that made it pass.

BLOCKED means the test cannot run on this DUT, and nothing was verified. A test is blocked when it needs `halted` and `trap`, when it needs a 4-bit `dmem_we`, or when its program uses an address beyond what `dmem_addr` can express. The current CPU has an 11-bit `dmem_addr`, so it reaches only `0x0000-0x07ff`, and every rv32ui test is blocked because it reports through `tohost` at `0x1ffc`. The log of each run names the reason for every blocked test. `RUN_BLOCKED=1` runs blocked tests anyway, for diagnosis; they still count as BLOCKED.

## Tests

The baseline programs are `smoke`, `no_branch`, `branch_only`, `jump_only`, `fullword`, `alu`, `wrap` and `control` in `sw/tests/asm/`, with expected words written in `test_cpu.py`, and `reset_rerun`, which runs `fullword` across three resets.

The directed programs are `isa_<instruction>.S`, one for each of the 37 instructions and for FENCE, ECALL and EBREAK, and `trap_*.S`, one for each illegal encoding and misaligned access the contract names. They use the macros in `sw/tests/asm/isa.h`: each case writes its result to a word `R(n)` in `0x400-0x7fc` and records the expected word in the section `.expect`, which the harness reads from the ELF and the CPU never sees. Every word not in `.expect` must keep its value from the program image. A trap program passes only when the CPU stops with `halted` and `trap` high and `tohost` still 0.

The rv32ui programs are the riscv-tests sources vendored in `sw/tests/riscv-tests/`, built with a local `riscv_test.h` that writes `tohost` without CSRs. Each passes when the CPU stops cleanly with `tohost` reading 1.

`coverage.csv` lists every test with the instruction or case it covers, the ports it needs and its edge cases, and `test_isa.py` takes its test list from that file. A program on disk without a row, or a row without a program, stops the run.

## Add a test

To add a directed instruction test, write `sw/tests/asm/isa_<name>.S` with the macros of `isa.h`, add a row to `coverage.csv`, and run `make -C sim/cocotb model` so that `check_programs.py` recomputes your expected words and finds the instruction in the disassembly. Then run `make -C sim/cocotb isa TESTCASE=isa_<name>`. A trap test is the same with the name `trap_<case>.S`, `halt` in the `needs` column and a comment `// encoding: 0x........` naming the faulting word, which `check_programs.py` looks for in the disassembly.

To add a baseline test, write the program in `sw/tests/asm/` and a cocotb test of the same name in `test_cpu.py` with its expected words.

## Memory timing

`memory_model.Bram` stores 8 KiB as 2048 little-endian words, selects the word with `addr[12:2]`, writes the lanes that `dmem_we` enables and returns the written word on a write, as WRITE_FIRST does. A 1-bit `dmem_we` writes all four lanes, which is what the CPU means by it; whether the block design's 1-bit net into `web[3:0]` does the same on hardware is unconfirmed. An enabled access at or above `0x2000` fails the test.

The port model runs at every falling edge: it drives `dmem_rdata` with the word for the previous request, then samples the request the BRAM sees at the next rising edge. This gives one cycle of read latency, which `read_latency_1` in `test_harness.py` measures end to end: a CPU that changes `dmem_addr` at one rising edge captures the data at the second rising edge after it. `MEM_LATENCY=2` adds one output register, as the old Verilog testbench did.

## End of a program

With `halted` and `trap` on the DUT, a program ends when `halted` goes high, clean with `trap` low and as a trap with `trap` high. Without them, a program ends when `jal x0, 0` is decoded twice in a row at the same address; the current core shows each decode only through `led`, which reads `4'b0010` for one cycle per instruction, and that is the testbed's only dependence on its FSM. Every program ends with `ecall` followed by `jal x0, 0`, so it stops on both cores. A run that reaches `MAX_CYCLES`, 10000 for directed and baseline tests and 100000 for rv32ui, fails as a timeout. Cycle counts are logged from the first rising edge after reset and never asserted.

## Negative experiments

Each of these must exit nonzero; undo the edit afterwards.

```sh
make -C sim/cocotb cpu TESTCASE=branch_only MEM_LATENCY=2     # lw returns its own instruction word
make -C sim/cocotb cpu TESTCASE=smoke MAX_CYCLES=20           # timeout
make -C sim/cocotb cpu TESTCASE=smok                          # no results file
echo isa_add >> sim/cocotb/known_failures.txt && make -C sim/cocotb isa TESTCASE=isa_add    # XPASS
```

Changing an expected word in `isa_add.S` fails both `make -C sim/cocotb model` and `make -C sim/cocotb isa TESTCASE=isa_add`. To check that a test catches a fault in the CPU, copy `cpu_top.v` outside the repository, change one line and pass it with `CPU=/path/to/copy.v BUILD=/tmp/mutant`; the separate `BUILD` keeps the simulator build of the real source apart.

## Not verified here

Simulation shows nothing about timing, utilization or the real `blk_mem_gen` netlist, the byte lane behaviour of the block design's `dmem_we` wiring, accesses from the PS through port A during a run, or board behaviour. The harness tests of the 32-bit address, the 4-bit `dmem_we` and `halted` and `trap` run on `stub_cpu.v`, a fixture with the planned port, not on a CPU. The expected words of the directed tests are checked against reference functions by the same author, so a misreading of the specification shared by both would pass.
