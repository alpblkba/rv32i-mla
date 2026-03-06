#ifndef RV32I_MLA_H
#define RV32I_MLA_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif


// public constants


// fixed accelerator tile size 
#define RV32I_MLA_DIM 4

// BRAM / mailbox layout with byte offsets 
#define RV32I_MLA_CMD_OFF       0x00
#define RV32I_MLA_STATUS_OFF    0x04
#define RV32I_MLA_CYCLES_OFF    0x08

// accelerator command encoding 
#define RV32I_MLA_CMD_LOAD_A    0u
#define RV32I_MLA_CMD_LOAD_B    1u
#define RV32I_MLA_CMD_COMPUTE   2u
#define RV32I_MLA_CMD_READ_C    3u

// status values (may evolve) 
#define RV32I_MLA_STATUS_IDLE   0u
#define RV32I_MLA_STATUS_BUSY   1u
#define RV32I_MLA_STATUS_DONE   2u

// default physical mapping parameters 
#define RV32I_MLA_DEFAULT_BASE  0x40000000u
#define RV32I_MLA_DEFAULT_SIZE  0x00002000u


// error handling

typedef enum {
    RV32I_MLA_OK = 0,
    RV32I_MLA_ERR_ARG = -1,
    RV32I_MLA_ERR_OPEN = -2,
    RV32I_MLA_ERR_MMAP = -3,
    RV32I_MLA_ERR_TIMEOUT = -4,
    RV32I_MLA_ERR_IO = -5
} rv32i_mla_status_t;

// opaque device handle
typedef struct rv32i_mla_dev rv32i_mla_dev_t;

// device lifecycle

/**
 * open and map the hardware control region.
 *
 * base_addr: physical base address of the mailbox / BRAM region
 * map_size : size of mapped region in bytes
 *
 * returns:
 *   non-NULL device handle on success
 *   NULL on failure
 */
rv32i_mla_dev_t *rv32i_mla_open(uint32_t base_addr, size_t map_size);

// close and release all resources associated with the device.
void rv32i_mla_close(rv32i_mla_dev_t *dev);

// raw register / mailbox access

// write a 32-bit value to a byte offset within the mapped region.
rv32i_mla_status_t rv32i_mla_write32(rv32i_mla_dev_t *dev, uint32_t offset, uint32_t value);

// read a 32-bit value from a byte offset within the mapped region.
rv32i_mla_status_t rv32i_mla_read32(rv32i_mla_dev_t *dev, uint32_t offset, uint32_t *value);


// mailbox helpers
// write a command value into the mailbox CMD location.
rv32i_mla_status_t rv32i_mla_write_cmd(rv32i_mla_dev_t *dev, uint32_t cmd);

// read the current mailbox STATUS value.
rv32i_mla_status_t rv32i_mla_read_status(rv32i_mla_dev_t *dev, uint32_t *status);

//read the current cycle counter / cycle measurement value.
rv32i_mla_status_t rv32i_mla_read_cycles(rv32i_mla_dev_t *dev, uint32_t *cycles);

// poll until STATUS reaches RV32I_MLA_STATUS_DONE or timeout expires.
// timeout_us: timeout in microseconds

rv32i_mla_status_t rv32i_mla_wait_done(rv32i_mla_dev_t *dev, uint32_t timeout_us);

// accelerator-oriented helpers
/**
 * load a 4x4 int8 matrix A into the accelerator-visible input format
 *
 * matrix is provided in row-major logical form.
 */
rv32i_mla_status_t rv32i_mla_load_matrix_a_i8(
    rv32i_mla_dev_t *dev,
    const int8_t a[RV32I_MLA_DIM][RV32I_MLA_DIM]
);

/**
 * load a 4x4 int8 matrix B into the accelerator-visible input format
 *
 * matrix is provided in row-major logical form.
 */
rv32i_mla_status_t rv32i_mla_load_matrix_b_i8(
    rv32i_mla_dev_t *dev,
    const int8_t b[RV32I_MLA_DIM][RV32I_MLA_DIM]
);

// start accelerator execution.
rv32i_mla_status_t rv32i_mla_start_accel(rv32i_mla_dev_t *dev);

// read back a 4x4 int32 output matrix C from the accelerator / mailbox path.
rv32i_mla_status_t rv32i_mla_read_matrix_c_i32(
    rv32i_mla_dev_t *dev,
    int32_t c[RV32I_MLA_DIM][RV32I_MLA_DIM]
);

/**
 * convenience wrapper:
 *   - load A
 *   - load B
 *   - start compute
 *   - wait for completion
 *   - read C
 *   - optionally read cycle count
 */
rv32i_mla_status_t rv32i_mla_run_matmul_i8(
    rv32i_mla_dev_t *dev,
    const int8_t a[RV32I_MLA_DIM][RV32I_MLA_DIM],
    const int8_t b[RV32I_MLA_DIM][RV32I_MLA_DIM],
    int32_t c[RV32I_MLA_DIM][RV32I_MLA_DIM],
    uint32_t *cycles
);

#ifdef __cplusplus
}
#endif

#endif /* RV32I_MLA_H */