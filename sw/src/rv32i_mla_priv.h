#ifndef RV32I_MLA_PRIV_H
#define RV32I_MLA_PRIV_H

#include <stddef.h>
#include <stdint.h>

#include "../include/rv32i_mla.h"

struct rv32i_mla_dev {
    int fd;
    uint32_t phys_base;
    size_t map_size;
    volatile uint8_t *base;
    rv32i_mla_hwcfg_t cfg;
};

rv32i_mla_status_t rv32i_mla_check_dev(const rv32i_mla_dev_t *dev);
rv32i_mla_status_t rv32i_mla_check_range(const rv32i_mla_dev_t *dev,
                                         uint32_t offset,
                                         size_t size_bytes);
rv32i_mla_status_t rv32i_mla_check_word_aligned(uint32_t offset);
uint32_t rv32i_mla_imem_offset(uint32_t byte_offset);
uint32_t rv32i_mla_dmem_offset(uint32_t byte_offset);

#endif
