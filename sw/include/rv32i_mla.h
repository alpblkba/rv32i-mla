#ifndef RV32I_MLA_H
#define RV32I_MLA_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define RV32I_MLA_DEFAULT_BASE  0x40000000u
#define RV32I_MLA_DEFAULT_SIZE  0x00002000u

#define RV32I_MLA_IMEM_BASE     0x0000u
#define RV32I_MLA_IMEM_SIZE     0x0100u

#define RV32I_MLA_DMEM_BASE     0x0100u
#define RV32I_MLA_DMEM_SIZE     0x0100u

#define RV32I_MLA_MMIO_BASE     0x0200u
#define RV32I_MLA_MMIO_SIZE     0x0100u

#define RV32I_MLA_MMIO_START    0x0200u
#define RV32I_MLA_MMIO_DONE     0x0204u
#define RV32I_MLA_MMIO_CYCLES   0x0208u

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

typedef struct {
    uint32_t phys_base;
    size_t   map_size;

    uint32_t imem_base;
    size_t   imem_size;

    uint32_t dmem_base;
    size_t   dmem_size;

    uint32_t mmio_base;
    size_t   mmio_size;

    uint8_t  has_run_ctrl;
    uint8_t  has_cycle_counter;
    uint8_t  has_accel_mailbox;
} rv32i_mla_hwcfg_t;

typedef struct rv32i_mla_dev rv32i_mla_dev_t;

rv32i_mla_dev_t *rv32i_mla_open(uint32_t base_addr, size_t map_size);
void rv32i_mla_close(rv32i_mla_dev_t *dev);

rv32i_mla_status_t rv32i_mla_get_default_hwcfg(rv32i_mla_hwcfg_t *cfg);
rv32i_mla_status_t rv32i_mla_get_hwcfg(rv32i_mla_dev_t *dev, rv32i_mla_hwcfg_t *cfg);

rv32i_mla_status_t rv32i_mla_write32(rv32i_mla_dev_t *dev, uint32_t offset, uint32_t value);
rv32i_mla_status_t rv32i_mla_read32(rv32i_mla_dev_t *dev, uint32_t offset, uint32_t *value);
rv32i_mla_status_t rv32i_mla_clear_window(rv32i_mla_dev_t *dev, uint32_t base, size_t size_bytes);

rv32i_mla_status_t rv32i_mla_write_imem_word(rv32i_mla_dev_t *dev, uint32_t byte_offset, uint32_t word);
rv32i_mla_status_t rv32i_mla_read_imem_word(rv32i_mla_dev_t *dev, uint32_t byte_offset, uint32_t *word);

rv32i_mla_status_t rv32i_mla_load_program_words(
    rv32i_mla_dev_t *dev,
    uint32_t imem_base,
    const uint32_t *words,
    size_t word_count
);

rv32i_mla_status_t rv32i_mla_load_program_bin(
    rv32i_mla_dev_t *dev,
    uint32_t imem_base,
    const char *path,
    size_t *words_loaded
);

rv32i_mla_status_t rv32i_mla_write_dmem_word(rv32i_mla_dev_t *dev, uint32_t byte_offset, uint32_t word);
rv32i_mla_status_t rv32i_mla_read_dmem_word(rv32i_mla_dev_t *dev, uint32_t byte_offset, uint32_t *word);

rv32i_mla_status_t rv32i_mla_write_dmem_block(
    rv32i_mla_dev_t *dev,
    uint32_t byte_offset,
    const uint32_t *words,
    size_t word_count
);

rv32i_mla_status_t rv32i_mla_read_dmem_block(
    rv32i_mla_dev_t *dev,
    uint32_t byte_offset,
    uint32_t *words,
    size_t word_count
);

rv32i_mla_status_t rv32i_mla_cpu_start(rv32i_mla_dev_t *dev);
rv32i_mla_status_t rv32i_mla_cpu_wait_done(rv32i_mla_dev_t *dev, uint32_t timeout_us);
rv32i_mla_status_t rv32i_mla_cpu_read_cycles(rv32i_mla_dev_t *dev, uint32_t *cycles);

#ifdef __cplusplus
}
#endif

#endif
