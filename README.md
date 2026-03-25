# rv32i-mla

A compact FPGA hardware/software co-design project built around a custom three-stage RV32I-subset processor and a fixed-function 4x4 int8 matrix multiplication accelerator.

This repository is intended as a teaching-quality and evaluation-quality project artifact. It documents a minimal but complete execution stack spanning RTL, FPGA block-design integration, Python-based board bring-up, and a user-space C driver/application layer. The implementation is deliberately narrow in scope: the goal is not full RISC-V platform completeness, but a clean, inspectable, and experimentally useful embedded compute system.

## 1. Project overview

The repository brings together four tightly connected components:

1. a custom **three-stage in-order RV32I-subset CPU** in Verilog
2. a **small matrix multiplication accelerator** in Verilog
3. an FPGA **block design / overlay flow** for deployment on a PYNQ-class Zynq platform
4. software utilities for **program staging, validation, diagnostics, and memory inspection**

The design philosophy is intentionally disciplined:

- keep the CPU simple enough to reason about at RTL level
- expose memory and control through a small shared address map
- use narrowly scoped instruction support rather than pseudo-complete ISA claims
- make the system easy to validate from simulation, notebook flow, and C user-space tooling

In the current repository state, the **CPU baseline is the central implemented and verified element**. The software stack and notebook flow are structured around loading binaries into a BRAM-backed memory image, letting the CPU execute them, and reading data-memory results back from the processing system side.

## 2. Repository structure

A typical repository organization for this project is conceptually divided into the following domains:

```text
rtl/      RTL sources for the CPU, accelerator, and testbenches
hw/       generated FPGA artifacts such as .bit and .hwh
sw/       C driver library, CLI application, build scripts, assembly utilities
notebooks/ or root notebook
          high-level overlay loading and board-side diagnostics
```

The uploaded project sources associated with this repository correspond to the following principal files:

```text
cpu_top.v
accelerator.v
rv32i_mla_bd.bit
rv32i_mla_bd.hwh
rv32i_mla_notebook.ipynb
rv32i_mla.h
rv32i_mla.c
rv32i_mla_priv.h
rv32i_mla_app.c
```

## 3. System architecture

At system level, the design is organized around a **shared BRAM-backed memory region** visible both to the processing system and to the programmable logic.

Conceptually:

```text
PS software / notebook / C app
        |
        | MMIO via mapped BRAM window
        v
+-------------------------------+
| instruction memory window     |
| data memory window            |
| reserved / control window     |
+-------------------------------+
        ^
        |
custom RV32I-subset CPU
        |
        +--> optional accelerator-facing extension path
```

The practical workflow is:

1. build or provide a raw program binary
2. stage it into the instruction-memory window from PS side
3. clear or prepare data memory
4. allow the CPU to run
5. inspect resulting data-memory words

This architecture keeps the system small and transparent. It avoids cache coherency, privilege levels, interrupts, MMUs, and bus fabrics more complex than necessary for the educational objective.

## 4. CPU microarchitecture

## 4.1 CPU role

`cpu_top.v` implements a compact 32-bit in-order processor with a **three-stage execution organization**:

1. **IF** — instruction fetch
2. **ID** — decode, register read, and immediate generation
3. **EX/MEM/WB** — execute, memory access sequencing, and write-back

The implementation is best understood as a **small staged controller** rather than a deeply decoupled high-performance pipeline. It preserves the conceptual structure of a three-stage processor while keeping control explicit and readable in RTL.

## 4.2 Top-level CPU interface

The current `cpu_top` module exposes the following hardware interface:

```verilog
module cpu_top (
    input  wire        clk,
    input  wire        rst_n,
    output reg  [3:0]  led,

    output reg         dmem_en,
    output reg         dmem_we,
    output reg  [10:0] dmem_addr,
    output reg  [31:0] dmem_wdata,
    input  wire [31:0] dmem_rdata
);
```

### Interface interpretation

- `clk`, `rst_n`: synchronous CPU clocking and active-low reset
- `led[3:0]`: coarse debug/state visibility for board-side observation
- `dmem_en`: memory port enable, held asserted in normal operation
- `dmem_we`: write enable for store operations
- `dmem_addr[10:0]`: 11-bit memory address driven by the CPU
- `dmem_wdata`: 32-bit data for stores
- `dmem_rdata`: 32-bit read data returned from memory

A notable feature of this interface is that **the same memory-facing port is used both for instruction fetch and data access**. The CPU therefore treats the BRAM-backed window as a unified addressable word store, with logical subregions reserved for instruction and data use.

## 4.3 Architectural state

The CPU contains the following principal architectural and microarchitectural state:

- `pc`: 32-bit program counter
- `regs[0:31]`: 32 general-purpose 32-bit registers
- `cycle_counter`: local cycle counter register in RTL
- `if_*` registers: fetch-stage latches
- `ex_*` registers: decode/execute pipeline latches
- `load_*` and `store_*` registers: state carried across memory follow-up states

The integer register file follows normal RISC-V register-zero semantics:

- `x0` is forced to zero every cycle
- writes to `x0` are ignored effectively by post-cycle correction

## 4.4 Processor state machine

Although architecturally organized as a three-stage CPU, the implementation uses explicit control states to handle the timing of BRAM-backed fetch and memory operations:

- `S_RESET`
- `S_IF_ADDR`
- `S_IF_WAIT`
- `S_ID`
- `S_EXWB`
- `S_LOAD_WAIT`
- `S_STORE_COMMIT`

This is important to understand correctly:

- the design is **three-stage in organization**
- but **multi-cycle in control realization** for fetch/load/store timing

That makes the implementation suitable for FPGA block RAM timing without pretending to be a fully overlapped textbook pipeline.

## 4.5 Stage-by-stage behavior

### IF: instruction fetch

Instruction fetch is split across address issue and wait behavior:

- the current `pc` is driven onto `dmem_addr`
- the memory read result is captured into `if_instr`
- `if_pc` stores the fetch PC associated with that instruction

Relevant states:

- `S_RESET` / `S_IF_ADDR`: drive fetch address
- `S_IF_WAIT`: capture `dmem_rdata` as instruction word

### ID: decode / register read / immediate generation

In `S_ID`, the processor:

- decodes opcode, funct3, funct7, rd, rs1, rs2
- reads register operands from `regs`
- generates the appropriate sign-extended immediate
- latches all execution inputs into `ex_*` registers

Supported immediate formats generated in the RTL:

- I-type immediate
- S-type immediate
- B-type immediate
- J-type immediate

### EX/MEM/WB: execute / access / commit

In `S_EXWB`, the processor:

- executes ALU operations for R-type and supported I-type instructions
- decides branch direction and target for branch instructions
- computes JAL link and target
- prepares memory addresses for loads/stores
- writes back ALU or link results where applicable

Loads and stores branch out into dedicated follow-up states:

- `S_LOAD_WAIT`: capture load result and write it to destination register
- `S_STORE_COMMIT`: assert write enable and commit store data

## 4.6 LED state encoding

The `led` output is used as a compact execution-state indicator:

- `4'b0001`: fetch path / reset / instruction address setup / fetch wait
- `4'b0010`: decode stage
- `4'b0100`: execute stage
- `4'b1000`: load completion or store commit stage

These LEDs are useful for coarse board-level debugging and for distinguishing whether the CPU is stuck during fetch, decode, execute, or memory completion behavior.

## 5. Supported ISA subset

## 5.1 Scope

The processor is **not full RV32I**. It implements a carefully selected subset sufficient for arithmetic tests, memory tests, simple control-flow tests, and software-managed diagnostics.

The currently visible RTL supports the following instruction classes.

### R-type

- `ADD`
- `SUB`
- `AND`
- `OR`

### I-type

- `ADDI`

### Loads

- `LW`

### Stores

- `SW`

### Branches

- `BEQ`
- `BNE`

### Jumps

- `JAL`

## 5.2 Opcode map

The current CPU RTL defines the following opcodes:

| Instruction class | Opcode (binary) | Opcode (hex) |
|---|---:|---:|
| R-type | `0110011` | `0x33` |
| I-type arithmetic | `0010011` | `0x13` |
| load | `0000011` | `0x03` |
| store | `0100011` | `0x23` |
| branch | `1100011` | `0x63` |
| JAL | `1101111` | `0x6F` |

## 5.3 Function decoding

### R-type funct3 / funct7 usage

| Instruction | funct3 | funct7 |
|---|---:|---:|
| `ADD` | `000` | `0000000` |
| `SUB` | `000` | `0100000` |
| `AND` | `111` | `0000000` |
| `OR`  | `110` | `0000000` |

### Branch funct3 usage

| Instruction | funct3 |
|---|---:|
| `BEQ` | `000` |
| `BNE` | `001` |

### Memory funct3 usage

| Instruction | funct3 |
|---|---:|
| `LW` | `010` |
| `SW` | `010` |

## 5.4 Unsupported instructions and non-goals

The current visible baseline does **not** implement, among others:

- `LUI`
- `AUIPC`
- `JALR`
- byte and halfword loads/stores
- shifts
- set-less-than operations
- multiply/divide extensions
- exceptions and traps
- interrupts
- CSR machinery
- privilege modes

Unsupported or unrecognized instructions fall through the default execution path and simply advance the PC without architecturally meaningful execution.

## 6. Program counter and control-flow behavior

The normal sequential next-PC rule is:

```text
pc_next_default = ex_pc + 4
```

Control flow behavior in the current RTL:

- `BEQ`: branch if `rs1 == rs2`
- `BNE`: branch if `rs1 != rs2`
- `JAL`: write `pc + 4` to `rd`, then set `pc = ex_pc + imm_j`

No dynamic prediction logic is present in the current visible `cpu_top.v` baseline. If the broader project description mentions a two-bit branch predictor, that should be understood as a project direction or an extension target rather than a feature demonstrated by this specific frozen CPU RTL file.

## 7. Memory model and addressing

## 7.1 CPU-side addressing

The CPU drives an **11-bit address bus**:

```verilog
output reg [10:0] dmem_addr
```

This means the memory-facing CPU address space is bounded by the width of that bus. In practice, the CPU uses low-order address bits of byte addresses and relies on the shared BRAM-backed system memory organization defined by the software layer.

The CPU fetch path uses:

```verilog
dmem_addr <= pc[10:0];
```

Load and store effective addresses are similarly reduced to the low 11 bits for memory access.

This is sufficient for the small instruction/data windows used by the project.

## 7.2 Software-visible address map

The public C header defines the default mapped PS-visible region as:

```c
#define RV32I_MLA_DEFAULT_BASE  0x40000000u
#define RV32I_MLA_DEFAULT_SIZE  0x00002000u
```

Within that mapped region, the software layer defines logical subregions:

| Region | Offset | Size | Purpose |
|---|---:|---:|---|
| IMEM | `0x0000` | `0x0100` | instruction words staged by software |
| DMEM | `0x0100` | `0x0100` | data memory results and scratch storage |
| MMIO / reserved | `0x0200` | `0x0100` | optional run control / future control window |

Macros from `rv32i_mla.h`:

```c
#define RV32I_MLA_IMEM_BASE     0x0000u
#define RV32I_MLA_IMEM_SIZE     0x0100u

#define RV32I_MLA_DMEM_BASE     0x0100u
#define RV32I_MLA_DMEM_SIZE     0x0100u

#define RV32I_MLA_MMIO_BASE     0x0200u
#define RV32I_MLA_MMIO_SIZE     0x0100u
```

This software map is central to the project. It gives a stable contract for:

- program staging into instruction memory
- result observation in data memory
- future MMIO-backed control if present in the deployed bitstream

## 7.3 Addressing convention used by diagnostic programs

The included software diagnostics commonly treat:

- `0x0100` as the first data-memory word location
- `0x0104` as the second data-memory word location

For example, the built-in smoke and arithmetic/control-flow diagnostics frequently store result values into those two DMEM locations for readback from the processing system side.

## 8. Load/store behavior

Only 32-bit word memory accesses are implemented in the visible baseline.

### Load path

For `LW`:

1. effective address is formed as `rs1 + imm_i`
2. address low bits are driven on `dmem_addr`
3. destination register is remembered in `load_rd`
4. `S_LOAD_WAIT` captures `dmem_rdata`
5. destination register is written if `rd != x0`

### Store path

For `SW`:

1. effective address is formed as `rs1 + imm_s`
2. address and store data are saved in `store_addr_q` / `store_data_q`
3. `S_STORE_COMMIT` asserts `dmem_we`
4. `dmem_wdata` is driven with the source operand value

This explicit sequencing simplifies timing and avoids hidden assumptions about same-cycle memory response.

## 9. Accelerator architecture

## 9.1 Accelerator purpose

`accelerator.v` implements a small fixed-function matrix multiply block intended for demonstrating tightly scoped hardware acceleration alongside the CPU.

The current accelerator operates on:

- **4x4 matrices**
- packed **signed 8-bit elements** for inputs
- **signed 32-bit accumulation** for outputs

The result matrix is stored internally in row-major order as 16 signed 32-bit values.

## 9.2 Accelerator interface

```verilog
module accelerator (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        cmd_valid,
    input  wire [1:0]  cmd_op,
    input  wire [31:0] rs1_val,
    input  wire [31:0] rs2_val,
    output reg         busy,
    output reg         resp_valid,
    output reg [31:0]  resp_data
);
```

### Command semantics

`cmd_op` is interpreted as:

| cmd_op | Meaning |
|---:|---|
| `0` | load one packed row of matrix A |
| `1` | load one packed row of matrix B |
| `2` | start compute |
| `3` | read one C element |

Software-facing constants in `rv32i_mla.h` mirror this intended command model:

```c
#define RV32I_MLA_ACCEL_DIM         4u
#define RV32I_MLA_ACCEL_CMD_LOAD_A  0u
#define RV32I_MLA_ACCEL_CMD_LOAD_B  1u
#define RV32I_MLA_ACCEL_CMD_COMPUTE 2u
#define RV32I_MLA_ACCEL_CMD_READ_C  3u
```

## 9.3 Internal organization

The accelerator stores:

- `A[0:3]`: four packed 32-bit rows of matrix A
- `B[0:3]`: four packed 32-bit rows of matrix B
- `C[0:15]`: sixteen signed 32-bit output elements

Each packed input row contains four signed 8-bit elements.

A helper function extracts individual signed bytes from each packed row. During computation, the accelerator calculates **one output element per cycle** while `busy` is asserted.

## 9.4 Compute schedule

When `cmd_op == 2` and the accelerator is idle:

- `busy` is asserted
- `compute_idx` starts at `0`
- each cycle computes one `C[row, col]`
- after `compute_idx == 15`, `busy` is deasserted

This gives a simple deterministic schedule for 4x4 matrix multiplication.

## 9.5 Current integration status

The accelerator RTL exists as a standalone module and the software API already reserves symbolic command values for it. However, the currently visible baseline CPU module does **not** directly instantiate or issue commands to the accelerator. Therefore, accelerator presence in this repository should be interpreted as:

- implemented RTL block
- planned or partial system integration path
- software-facing contract already anticipated in headers

rather than as a claim that the baseline `cpu_top.v` currently dispatches accelerator operations from the instruction stream.

## 10. Software layer

## 10.1 Role of the C driver

The C software layer provides a user-space abstraction over the BRAM-backed mapped hardware region. It allows software to:

- open the mapped device window
- read and write 32-bit words
- clear IMEM, DMEM, and reserved windows
- stage program words or raw binaries into instruction memory
- read back data-memory results
- query declared hardware configuration
- optionally attempt run control if the bitstream exposes it

The design is intentionally small and explicit. It is a memory-mapped runtime utility layer, not a generic emulator or SDK.

## 10.2 Public API header

The main public entry point is `rv32i_mla.h`.

### Public types

- `rv32i_mla_status_t`: unified status/error enum
- `rv32i_mla_hwcfg_t`: declared hardware configuration and capability flags
- `rv32i_mla_dev_t`: opaque device handle

### Status model

The public status enum is:

```c
typedef enum {
    RV32I_MLA_OK              =  0,
    RV32I_MLA_ERR_ARG         = -1,
    RV32I_MLA_ERR_OPEN        = -2,
    RV32I_MLA_ERR_MMAP        = -3,
    RV32I_MLA_ERR_IO          = -4,
    RV32I_MLA_ERR_TIMEOUT     = -5,
    RV32I_MLA_ERR_RANGE       = -6,
    RV32I_MLA_ERR_FORMAT      = -7,
    RV32I_MLA_ERR_UNSUPPORTED = -8,
    RV32I_MLA_ERR_STATE       = -9
} rv32i_mla_status_t;
```

This is a strong design decision because it keeps all library calls on a consistent error-reporting model.

### Declared hardware capability fields

`rv32i_mla_hwcfg_t` includes capability flags:

- `has_run_ctrl`
- `has_cycle_counter`
- `has_accel_mailbox`

In the current local software default configuration, these are conservatively disabled unless a bitstream explicitly supports them.

## 10.3 Core API functions

The library provides the following major functions.

### Device lifecycle

- `rv32i_mla_open(base_addr, map_size)`
- `rv32i_mla_close(dev)`

These functions open and close the mapped physical-memory device abstraction.

### Configuration queries

- `rv32i_mla_get_default_hwcfg(cfg)`
- `rv32i_mla_get_hwcfg(dev, cfg)`

### Raw 32-bit access

- `rv32i_mla_write32(dev, offset, value)`
- `rv32i_mla_read32(dev, offset, &value)`
- `rv32i_mla_clear_window(dev, base, size_bytes)`

### Instruction-memory helpers

- `rv32i_mla_write_imem_word(dev, byte_offset, word)`
- `rv32i_mla_read_imem_word(dev, byte_offset, &word)`
- `rv32i_mla_load_program_words(dev, imem_base, words, word_count)`
- `rv32i_mla_load_program_bin(dev, imem_base, path, &words_loaded)`

### Data-memory helpers

- `rv32i_mla_write_dmem_word(dev, byte_offset, word)`
- `rv32i_mla_read_dmem_word(dev, byte_offset, &word)`
- `rv32i_mla_write_dmem_block(dev, byte_offset, words, word_count)`
- `rv32i_mla_read_dmem_block(dev, byte_offset, words, word_count)`

### Optional run-control helpers

- `rv32i_mla_cpu_start(dev)`
- `rv32i_mla_cpu_wait_done(dev, timeout_us)`
- `rv32i_mla_cpu_read_cycles(dev, &cycles)`

These functions are part of the stable public API but may return `RV32I_MLA_ERR_UNSUPPORTED` when the active bitstream does not provide those control registers.

## 10.4 Software design properties

The software layer performs careful validation for:

- null arguments
- invalid device state
- word alignment
- range checking against the mapped window
- binary file formatting constraints for program loading

This is particularly important in a hardware-facing project, because accidental misalignment or out-of-range writes can silently corrupt diagnostics.

## 10.5 CLI application

`rv32i_mla_app.c` provides a command-line application for board-side staging and diagnostics.

### Supported commands

The app usage includes the following commands:

```text
info
ps_sanity
smoke
no_branch
branch_only
jump_only
stage_bin <path-to-bin>
dump_imem <word-count>
dump_dmem <word-count>
results
```

### Command intent

- `info`: print current software-declared configuration and capability flags
- `ps_sanity`: verify PS-side raw read/write through the mapped window
- `smoke`: minimal execution sanity case
- `no_branch`: arithmetic + stores without branch dependence
- `branch_only`: branch validation sequence
- `jump_only`: JAL validation sequence
- `stage_bin`: load an externally built raw binary into IMEM
- `dump_imem`: inspect staged instruction words
- `dump_dmem`: inspect data-memory words
- `results`: print the first two canonical result words

### Built-in instruction encoders

The app includes helper encoders for generating test programs directly in C:

- `enc_r`
- `enc_i`
- `enc_s`
- `enc_b`
- `enc_j`

and convenience wrappers such as:

- `rv_add`
- `rv_addi`
- `rv_lw`
- `rv_sw`
- `rv_beq`
- `rv_jal`

These make the diagnostic app self-contained and reduce dependence on an external assembler for small smoke tests.

## 11. Notebook bring-up layer

The notebook serves as the **high-level runtime management and validation layer** for the project.

Its responsibilities include:

- loading the FPGA overlay
- locating the relevant BRAM-backed memory region
- clearing windows
- staging prebuilt binaries into instruction memory
- allowing execution
- reading back data memory and validating test outputs

The notebook assumes a fixed supported instruction subset aligned with the current CPU baseline:

- `ADD`, `SUB`, `AND`, `OR`
- `ADDI`
- `LW`, `SW`
- `BEQ`, `BNE`
- `JAL`

and does not assume support for `LUI` or `JALR`.

This is a strength of the repository: the notebook is not generic theater, but a focused bring-up tool matched to the implemented CPU.

## 12. Build and validation flow

The project supports multiple validation layers.

## 12.1 RTL-level validation

At RTL level, the CPU and accelerator can be simulated and reasoned about independently. The CPU RTL is especially suitable for targeted micro-diagnostic programs because its state machine and memory interface are explicit.

## 12.2 Board-side validation

Board-side validation proceeds through one of two paths:

### Notebook path

1. load the `.bit` / `.hwh` overlay
2. identify the BRAM-backed memory region
3. clear instruction and data windows
4. stage a test binary
5. run or manually trigger execution depending on integration style
6. inspect DMEM values and compare against expectations

### C application path

1. open the mapped BRAM window through the driver
2. clear IMEM, DMEM, and reserved window
3. stage built-in or external test program
4. optionally attempt run control if supported
5. read back results

## 12.3 Example expected diagnostic patterns

The current diagnostics commonly use the following convention:

- result value 0 at `DMEM[0x0100]`
- result value 1 at `DMEM[0x0104]`

This makes regression-style checking simple and transparent.

## 13. Current implementation status

The repository should be understood with the following precision.

### Present and visible in current sources

- compact three-stage RV32I-subset CPU
- explicit fetch/decode/execute sequencing with load/store follow-up states
- unified BRAM-style memory interface
- software-visible IMEM/DMEM/MMIO partitioning
- standalone 4x4 int8-to-int32 matrix multiplication accelerator RTL
- notebook-based bring-up flow
- user-space C driver and CLI diagnostics

### Reserved or optional depending on deployed bitstream

- explicit run-control MMIO (`START`, `DONE`)
- cycle-counter MMIO exposure
- accelerator mailbox exposure through shared mapped control space

### Not demonstrated by the current visible `cpu_top.v`

- full RV32I compliance
- direct CPU instruction-stream integration with the accelerator
- dynamic branch predictor implementation inside the frozen baseline CPU RTL

This distinction is important for technical correctness. The README describes the project faithfully while avoiding claims beyond the visible baseline.

## 14. Design limitations

The project intentionally accepts a number of limitations.

- narrow ISA subset only
- no exceptions, traps, interrupts, or CSR support
- no privilege architecture
- no cache hierarchy
- unified small memory interface
- no direct accelerator issue path in the visible CPU baseline
- limited address space due to compact memory interface width
- control-oriented implementation rather than throughput-oriented superscalar design
  
## Suggested usage model

For practical use, the intended operating model is:

1. treat the CPU as the primary execution engine
2. use the notebook or C application to stage binaries and inspect memory
3. use the built-in diagnostics first before larger programs
4. regard the accelerator as a focused compute extension block
5. keep a strict distinction between **implemented baseline features** and **reserved extension hooks**

