# Software layer (sw)

This directory contains the software interface used to control the RV32I-MLA hardware design from the processing system.

The goal of this layer is to provide a clean **hardware–software boundary** between the programmable logic and user-facing software such as Python notebooks.

The software stack is structured as follows:



Python / Jupyter Notebook
            │
            ▼
C userspace control library
            │
            ▼
MMIO / mailbox interface
            │
            ▼
PL hardware (CPU + accelerator + BRAM)


The C layer is responsible for:

- mapping the hardware memory region
- implementing the mailbox protocol
- controlling accelerator execution
- transferring matrices between software and hardware
- collecting execution metrics (cycle counts)

Python notebooks remain the **orchestration and demonstration layer**, while the C code handles **low-level interaction with the hardware**.

## Directory Structure

'''
sw/
├── include/    public API headers
├── src/        C implementation (library + demo programs)
└── README.md
'''