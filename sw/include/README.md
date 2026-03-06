# Public hardware control API

This directory contains the **public header files** that define the software interface to the RV32I-MLA hardware system.

Currently the main interface is defined in:
'''
rv32i_mla.h
'''

This header describes the API used by software to interact with the hardware accelerator through memory-mapped I/O.

---

# Purpose of the header

The header defines the **contract between software and hardware**.

Instead of allowing higher-level code (Python, demos, benchmarks) to manipulate hardware registers directly, the header exposes a structured API that:

- hides low-level memory-mapping details
- formalizes the mailbox protocol
- provides helper functions for accelerator operations
- keeps hardware-specific constants in one location

This separation improves maintainability and makes the project resemble a real embedded software component rather than a collection of scripts.

---

# Architecture overview

The software stack for the project is organized in three layers:


Python / Jupyter
        │
        │  (high-level orchestration, demos, visualization)
        ▼
C control layer
        │
        │  (mailbox protocol, MMIO, matrix transfer)
        ▼
Programmable logic (PL)
        ├─ RV32I CPU
        ├─ Matrix Accelerator
        └─ BRAM / AXI interface


Python loads the FPGA overlay and provides input data. The C layer manages all low-level hardware communication.

---

# API structure

The header organizes the interface into several conceptual groups.

## 1. Public constants

These constants describe the hardware interface:

- matrix tile dimensions
- mailbox register offsets
- command encodings
- status values
- default physical address ranges

Example:
'''
RV32I_MLA_CMD_OFF
RV32I_MLA_STATUS_OFF
RV32I_MLA_CYCLES_OFF
'''

These values correspond directly to the mailbox layout implemented in hardware.

---

## 2. Error handling

The API returns explicit status codes:
'''
RV32I_MLA_OK
RV32I_MLA_ERR_ARG
RV32I_MLA_ERR_OPEN
RV32I_MLA_ERR_MMAP
RV32I_MLA_ERR_TIMEOUT
RV32I_MLA_ERR_IO
'''

This makes hardware interaction easier to debug and avoids ambiguous return values.

---

## 3. Device handle

The API uses an **opaque device handle**:
'''
typedef struct rv32i_mla_dev rv32i_mla_dev_t;
'''

The internal structure is hidden inside the implementation (`.c` file).

This allows the implementation to manage:

- file descriptors
- mapped memory regions
- internal state

without exposing these details to higher-level code.

---

## 4. Device lifecycle

The first step is to open and map the hardware control region.

Example flow:
'''
rv32i_mla_dev_t *dev = rv32i_mla_open(base_addr, size);
…
rv32i_mla_close(dev);
'''

This performs:

1. `/dev/mem` access
2. memory mapping of the BRAM region
3. initialization of the device context

---

## 5. Raw register access

Low-level register access is available through:
'''
rv32i_mla_write32()
rv32i_mla_read32()
'''

These functions allow direct interaction with the memory-mapped region.

They are mainly useful for:

- debugging
- bring-up
- testing new registers

Higher-level code normally uses the mailbox helper functions instead.

---

## 6. Mailbox helpers

The mailbox protocol is the primary communication mechanism between PS and PL.

The API exposes helper functions such as:
'''
rv32i_mla_write_cmd()
rv32i_mla_read_status()
rv32i_mla_read_cycles()
rv32i_mla_wait_done()
'''

These functions implement the command-status interaction used by the accelerator.

Typical execution flow:
'''
write CMD
poll STATUS
read CYCLES
'''

---

## 7. Accelerator helpers

The API also provides domain-specific functions for matrix operations:
'''
rv32i_mla_load_matrix_a_i8()
rv32i_mla_load_matrix_b_i8()
rv32i_mla_start_accel()
rv32i_mla_read_matrix_c_i32()
'''

These functions abstract the details of how matrices are packed and transferred to the hardware accelerator.

Software can therefore work with standard matrix representations while the C layer handles the hardware-specific format.

---

## 8. Convenience execution wrapper

For simple use cases, the API provides:
'''
rv32i_mla_run_matmul_i8()
'''

This function performs the full sequence:

1. load matrix A
2. load matrix B
3. start accelerator
4. wait for completion
5. read result matrix
6. optionally return cycle count

This is particularly useful for benchmarking and Python integration.

---

# Typical usage flow

A typical program using this API would follow these steps:

1. Open the device
2. Load input matrices
3. Start accelerator execution
4. Wait for completion
5. Read results
6. Close the device

Example outline:
'''
rv32i_mla_dev_t *dev = rv32i_mla_open(BASE, SIZE);

rv32i_mla_load_matrix_a_i8(dev, A);
rv32i_mla_load_matrix_b_i8(dev, B);

rv32i_mla_start_accel(dev);
rv32i_mla_wait_done(dev, timeout);

rv32i_mla_read_matrix_c_i32(dev, C);

rv32i_mla_close(dev);
'''

---

# Design goals

The API is designed to:

- separate hardware control from demonstration code
- encapsulate low-level MMIO operations
- make accelerator interaction predictable and reusable
- provide a foundation for future extensions (e.g. kernel driver)

This structure allows the project to evolve from a simple FPGA prototype into a more realistic hardware/software system.