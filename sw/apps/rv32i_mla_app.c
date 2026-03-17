#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>

#include "rv32i_mla.h"

#define APP_WAIT_MS_DEFAULT 50U

typedef struct {
    uint32_t base_addr;
    size_t map_size;
    unsigned wait_ms;
    int try_run;
} app_options_t;

typedef struct {
    const char *name;
    const char *note;
    const uint32_t *program;
    size_t word_count;
    int expect_dmem0_valid;
    uint32_t expect_dmem0;
    int expect_dmem1_valid;
    uint32_t expect_dmem1;
} diag_test_t;

static void print_usage(const char *prog)
{
    printf("usage:\n");
    printf("  %s [--base 0x40000000] [--size 0x2000] [--wait-ms 50] [--try-run] info\n", prog);
    printf("  %s [opts] ps_sanity\n", prog);
    printf("  %s [opts] smoke\n", prog);
    printf("  %s [opts] no_branch\n", prog);
    printf("  %s [opts] branch_only\n", prog);
    printf("  %s [opts] jump_only\n", prog);
    printf("  %s [opts] stage_bin <path-to-bin>\n", prog);
    printf("  %s [opts] dump_imem <word-count>\n", prog);
    printf("  %s [opts] dump_dmem <word-count>\n", prog);
    printf("  %s [opts] results\n", prog);
    printf("\n");
    printf("notes:\n");
    printf("  --try-run only works if the bitstream exposes MMIO run control.\n");
    printf("  otherwise the app only stages IMEM/DMEM and then waits for manual execution.\n");
}

static const char *status_str(rv32i_mla_status_t st)
{
    switch (st) {
    case RV32I_MLA_OK:              return "RV32I_MLA_OK";
    case RV32I_MLA_ERR_ARG:         return "RV32I_MLA_ERR_ARG";
    case RV32I_MLA_ERR_OPEN:        return "RV32I_MLA_ERR_OPEN";
    case RV32I_MLA_ERR_MMAP:        return "RV32I_MLA_ERR_MMAP";
    case RV32I_MLA_ERR_IO:          return "RV32I_MLA_ERR_IO";
    case RV32I_MLA_ERR_TIMEOUT:     return "RV32I_MLA_ERR_TIMEOUT";
    case RV32I_MLA_ERR_RANGE:       return "RV32I_MLA_ERR_RANGE";
    case RV32I_MLA_ERR_FORMAT:      return "RV32I_MLA_ERR_FORMAT";
    case RV32I_MLA_ERR_UNSUPPORTED: return "RV32I_MLA_ERR_UNSUPPORTED";
    case RV32I_MLA_ERR_STATE:       return "RV32I_MLA_ERR_STATE";
    default:                        return "RV32I_MLA_ERR_UNKNOWN";
    }
}

static void print_status_error(const char *what, rv32i_mla_status_t st)
{
    fprintf(stderr, "%s failed: %s (%d)\n", what, status_str(st), (int)st);
}

static void print_word_line(const char *label, uint32_t addr, uint32_t value)
{
    printf("%s @ 0x%08x = 0x%08x (%u)\n", label, addr, value, value);
}

static uint32_t enc_r(uint32_t funct7,
                      uint32_t rs2,
                      uint32_t rs1,
                      uint32_t funct3,
                      uint32_t rd,
                      uint32_t opcode)
{
    return ((funct7 & 0x7FU) << 25) |
           ((rs2    & 0x1FU) << 20) |
           ((rs1    & 0x1FU) << 15) |
           ((funct3 & 0x07U) << 12) |
           ((rd     & 0x1FU) <<  7) |
           ((opcode & 0x7FU) <<  0);
}

static uint32_t enc_i(int32_t imm,
                      uint32_t rs1,
                      uint32_t funct3,
                      uint32_t rd,
                      uint32_t opcode)
{
    uint32_t uimm = (uint32_t)imm & 0xFFFU;
    return (uimm             << 20) |
           ((rs1 & 0x1FU)    << 15) |
           ((funct3 & 0x07U) << 12) |
           ((rd & 0x1FU)     <<  7) |
           ((opcode & 0x7FU) <<  0);
}

static uint32_t enc_s(int32_t imm,
                      uint32_t rs2,
                      uint32_t rs1,
                      uint32_t funct3,
                      uint32_t opcode)
{
    uint32_t uimm = (uint32_t)imm & 0xFFFU;
    uint32_t imm_11_5 = (uimm >> 5) & 0x7FU;
    uint32_t imm_4_0 = uimm & 0x1FU;

    return (imm_11_5         << 25) |
           ((rs2 & 0x1FU)    << 20) |
           ((rs1 & 0x1FU)    << 15) |
           ((funct3 & 0x07U) << 12) |
           (imm_4_0          <<  7) |
           ((opcode & 0x7FU) <<  0);
}

static uint32_t enc_b(int32_t imm,
                      uint32_t rs2,
                      uint32_t rs1,
                      uint32_t funct3,
                      uint32_t opcode)
{
    uint32_t uimm = (uint32_t)imm & 0x1FFFU;
    uint32_t bit12 = (uimm >> 12) & 0x1U;
    uint32_t bit11 = (uimm >> 11) & 0x1U;
    uint32_t bits10_5 = (uimm >> 5) & 0x3FU;
    uint32_t bits4_1 = (uimm >> 1) & 0x0FU;

    return (bit12            << 31) |
           (bits10_5         << 25) |
           ((rs2 & 0x1FU)    << 20) |
           ((rs1 & 0x1FU)    << 15) |
           ((funct3 & 0x07U) << 12) |
           (bits4_1          <<  8) |
           (bit11            <<  7) |
           ((opcode & 0x7FU) <<  0);
}

static uint32_t enc_j(int32_t imm,
                      uint32_t rd,
                      uint32_t opcode)
{
    uint32_t uimm = (uint32_t)imm & 0x1FFFFFU;
    uint32_t bit20 = (uimm >> 20) & 0x1U;
    uint32_t bits10_1 = (uimm >> 1) & 0x3FFU;
    uint32_t bit11 = (uimm >> 11) & 0x1U;
    uint32_t bits19_12 = (uimm >> 12) & 0x0FFU;

    return (bit20            << 31) |
           (bits19_12        << 12) |
           (bit11            << 20) |
           (bits10_1         << 21) |
           ((rd & 0x1FU)     <<  7) |
           ((opcode & 0x7FU) <<  0);
}

static uint32_t rv_add(uint32_t rd, uint32_t rs1, uint32_t rs2)
{
    return enc_r(0x00U, rs2, rs1, 0x0U, rd, 0x33U);
}

static uint32_t rv_addi(uint32_t rd, uint32_t rs1, int32_t imm)
{
    return enc_i(imm, rs1, 0x0U, rd, 0x13U);
}

static uint32_t rv_lw(uint32_t rd, uint32_t rs1, int32_t imm)
{
    return enc_i(imm, rs1, 0x2U, rd, 0x03U);
}

static uint32_t rv_sw(uint32_t rs2, uint32_t rs1, int32_t imm)
{
    return enc_s(imm, rs2, rs1, 0x2U, 0x23U);
}

static uint32_t rv_beq(uint32_t rs1, uint32_t rs2, int32_t imm)
{
    return enc_b(imm, rs2, rs1, 0x0U, 0x63U);
}

static uint32_t rv_jal(uint32_t rd, int32_t imm)
{
    return enc_j(imm, rd, 0x6FU);
}

static void init_programs(uint32_t *smoke,
                          uint32_t *no_branch,
                          uint32_t *branch_only,
                          uint32_t *jump_only)
{
    smoke[0] = rv_addi(1, 0, 12);
    smoke[1] = rv_sw(1, 0, 0x100);
    smoke[2] = rv_jal(0, 0);

    no_branch[0] = rv_addi(1, 0, 5);
    no_branch[1] = rv_addi(2, 0, 7);
    no_branch[2] = rv_add(3, 1, 2);
    no_branch[3] = rv_sw(3, 0, 0x100);
    no_branch[4] = rv_addi(5, 0, 2);
    no_branch[5] = rv_sw(5, 0, 0x104);
    no_branch[6] = rv_jal(0, 0);

    branch_only[0] = rv_addi(1, 0, 5);
    branch_only[1] = rv_addi(2, 0, 7);
    branch_only[2] = rv_add(3, 1, 2);
    branch_only[3] = rv_sw(3, 0, 0x100);
    branch_only[4] = rv_lw(4, 0, 0x100);
    branch_only[5] = rv_beq(3, 4, 8);
    branch_only[6] = rv_addi(5, 0, 1);
    branch_only[7] = rv_addi(5, 0, 2);
    branch_only[8] = rv_sw(5, 0, 0x104);
    branch_only[9] = rv_jal(0, 0);

    jump_only[0] = rv_addi(1, 0, 5);
    jump_only[1] = rv_addi(2, 0, 7);
    jump_only[2] = rv_add(3, 1, 2);
    jump_only[3] = rv_sw(3, 0, 0x100);
    jump_only[4] = rv_jal(0, 8);
    jump_only[5] = rv_addi(5, 0, 1);
    jump_only[6] = rv_addi(5, 0, 2);
    jump_only[7] = rv_sw(5, 0, 0x104);
    jump_only[8] = rv_jal(0, 0);
}

static diag_test_t *find_test(const char *name, diag_test_t *tests, size_t count)
{
    size_t i;
    for (i = 0; i < count; ++i) {
        if (strcmp(name, tests[i].name) == 0) {
            return &tests[i];
        }
    }
    return NULL;
}

static int app_clear_stage_windows(rv32i_mla_dev_t *dev)
{
    rv32i_mla_status_t st;

    st = rv32i_mla_clear_window(dev, RV32I_MLA_IMEM_BASE, RV32I_MLA_IMEM_SIZE);
    if (st != RV32I_MLA_OK) {
        print_status_error("clear IMEM", st);
        return 1;
    }

    st = rv32i_mla_clear_window(dev, RV32I_MLA_DMEM_BASE, RV32I_MLA_DMEM_SIZE);
    if (st != RV32I_MLA_OK) {
        print_status_error("clear DMEM", st);
        return 1;
    }

    st = rv32i_mla_clear_window(dev, RV32I_MLA_MMIO_BASE, RV32I_MLA_MMIO_SIZE);
    if (st != RV32I_MLA_OK) {
        print_status_error("clear MMIO window", st);
        return 1;
    }

    return 0;
}

static int app_maybe_trigger_run(rv32i_mla_dev_t *dev, const app_options_t *opts)
{
    rv32i_mla_status_t st;

    if (opts->try_run == 0) {
        if (opts->wait_ms != 0U) {
            usleep(opts->wait_ms * 1000U);
        }
        return 0;
    }

    st = rv32i_mla_cpu_start(dev);
    if (st == RV32I_MLA_ERR_UNSUPPORTED) {
        printf("run control not present in this bitstream; staged only\n");
        if (opts->wait_ms != 0U) {
            usleep(opts->wait_ms * 1000U);
        }
        return 0;
    }
    if (st != RV32I_MLA_OK) {
        print_status_error("cpu_start", st);
        return 1;
    }

    st = rv32i_mla_cpu_wait_done(dev, 1000000U);
    if (st == RV32I_MLA_ERR_UNSUPPORTED) {
        return 0;
    }
    if (st != RV32I_MLA_OK) {
        print_status_error("cpu_wait_done", st);
        return 1;
    }

    return 0;
}

static int app_dump_imem(rv32i_mla_dev_t *dev, size_t word_count)
{
    size_t i;
    rv32i_mla_status_t st;
    uint32_t word;

    for (i = 0; i < word_count; ++i) {
        st = rv32i_mla_read_imem_word(dev, (uint32_t)(i * 4U), &word);
        if (st != RV32I_MLA_OK) {
            print_status_error("read IMEM word", st);
            return 1;
        }
        printf("IMEM[%02zu] @ 0x%08x = 0x%08x\n",
               i, RV32I_MLA_IMEM_BASE + (uint32_t)(i * 4U), word);
    }
    return 0;
}

static int app_dump_dmem(rv32i_mla_dev_t *dev, size_t word_count)
{
    size_t i;
    rv32i_mla_status_t st;
    uint32_t word;

    for (i = 0; i < word_count; ++i) {
        st = rv32i_mla_read_dmem_word(dev, (uint32_t)(i * 4U), &word);
        if (st != RV32I_MLA_OK) {
            print_status_error("read DMEM word", st);
            return 1;
        }
        printf("DMEM[%02zu] @ 0x%08x = 0x%08x\n",
               i, RV32I_MLA_DMEM_BASE + (uint32_t)(i * 4U), word);
    }
    return 0;
}

static int app_print_results(rv32i_mla_dev_t *dev)
{
    rv32i_mla_status_t st;
    uint32_t d0;
    uint32_t d1;

    st = rv32i_mla_read_dmem_word(dev, 0x00U, &d0);
    if (st != RV32I_MLA_OK) {
        print_status_error("read DMEM[0]", st);
        return 1;
    }

    st = rv32i_mla_read_dmem_word(dev, 0x04U, &d1);
    if (st != RV32I_MLA_OK) {
        print_status_error("read DMEM[1]", st);
        return 1;
    }

    print_word_line("DMEM[0x0100]", RV32I_MLA_DMEM_BASE + 0x00U, d0);
    print_word_line("DMEM[0x0104]", RV32I_MLA_DMEM_BASE + 0x04U, d1);
    return 0;
}

static int app_check_expectations(rv32i_mla_dev_t *dev, const diag_test_t *test)
{
    rv32i_mla_status_t st;
    uint32_t d0 = 0U;
    uint32_t d1 = 0U;
    int ok = 1;

    if (test->expect_dmem0_valid) {
        st = rv32i_mla_read_dmem_word(dev, 0x00U, &d0);
        if (st != RV32I_MLA_OK) {
            print_status_error("read expected DMEM[0]", st);
            return 1;
        }
        if (d0 != test->expect_dmem0) {
            fprintf(stderr, "%s: expected DMEM[0x0100] = %u, got %u\n",
                    test->name, test->expect_dmem0, d0);
            ok = 0;
        }
    }

    if (test->expect_dmem1_valid) {
        st = rv32i_mla_read_dmem_word(dev, 0x04U, &d1);
        if (st != RV32I_MLA_OK) {
            print_status_error("read expected DMEM[1]", st);
            return 1;
        }
        if (d1 != test->expect_dmem1) {
            fprintf(stderr, "%s: expected DMEM[0x0104] = %u, got %u\n",
                    test->name, test->expect_dmem1, d1);
            ok = 0;
        }
    }

    if (ok) {
        printf("%s PASS\n", test->name);
        return 0;
    }

    return 1;
}

static int app_stage_words(rv32i_mla_dev_t *dev,
                           const diag_test_t *test,
                           const app_options_t *opts)
{
    rv32i_mla_status_t st;

    printf("staging test: %s\n", test->name);
    printf("note: %s\n", test->note);

    if (app_clear_stage_windows(dev) != 0) {
        return 1;
    }

    st = rv32i_mla_load_program_words(dev,
                                      RV32I_MLA_IMEM_BASE,
                                      test->program,
                                      test->word_count);
    if (st != RV32I_MLA_OK) {
        print_status_error("load program words", st);
        return 1;
    }

    printf("loaded %zu words into IMEM\n", test->word_count);
    return app_maybe_trigger_run(dev, opts);
}

static int app_stage_bin(rv32i_mla_dev_t *dev,
                         const char *path,
                         const app_options_t *opts)
{
    rv32i_mla_status_t st;
    size_t words_loaded;

    if (app_clear_stage_windows(dev) != 0) {
        return 1;
    }

    st = rv32i_mla_load_program_bin(dev,
                                    RV32I_MLA_IMEM_BASE,
                                    path,
                                    &words_loaded);
    if (st != RV32I_MLA_OK) {
        print_status_error("load program bin", st);
        return 1;
    }

    printf("loaded %zu words from %s\n", words_loaded, path);
    return app_maybe_trigger_run(dev, opts);
}

static int app_ps_sanity(rv32i_mla_dev_t *dev)
{
    rv32i_mla_status_t st;
    uint32_t wr = 0x11223344U;
    uint32_t rd = 0U;

    st = rv32i_mla_write32(dev, RV32I_MLA_MMIO_BASE, wr);
    if (st != RV32I_MLA_OK) {
        print_status_error("write raw sanity word", st);
        return 1;
    }

    st = rv32i_mla_read32(dev, RV32I_MLA_MMIO_BASE, &rd);
    if (st != RV32I_MLA_OK) {
        print_status_error("read raw sanity word", st);
        return 1;
    }

    print_word_line("PS sanity echo", RV32I_MLA_MMIO_BASE, rd);
    if (rd != wr) {
        fprintf(stderr, "sanity mismatch: wrote 0x%08x, read 0x%08x\n", wr, rd);
        return 1;
    }

    printf("ps_sanity PASS\n");
    return 0;
}

static int app_print_info(rv32i_mla_dev_t *dev)
{
    rv32i_mla_hwcfg_t cfg;
    rv32i_mla_status_t st;

    st = rv32i_mla_get_hwcfg(dev, &cfg);
    if (st != RV32I_MLA_OK) {
        print_status_error("get_hwcfg", st);
        return 1;
    }

    printf("phys_base         : 0x%08x\n", cfg.phys_base);
    printf("map_size          : 0x%zx\n", cfg.map_size);
    printf("imem_base/size    : 0x%08x / 0x%zx\n", cfg.imem_base, cfg.imem_size);
    printf("dmem_base/size    : 0x%08x / 0x%zx\n", cfg.dmem_base, cfg.dmem_size);
    printf("mmio_base/size    : 0x%08x / 0x%zx\n", cfg.mmio_base, cfg.mmio_size);
    printf("has_run_ctrl      : %u\n", (unsigned)cfg.has_run_ctrl);
    printf("has_cycle_counter : %u\n", (unsigned)cfg.has_cycle_counter);
    printf("has_accel_mailbox : %u\n", (unsigned)cfg.has_accel_mailbox);
    return 0;
}

static int parse_u32_arg(const char *s, uint32_t *value)
{
    unsigned long v;
    char *end;

    if (s == NULL || value == NULL) {
        return 0;
    }

    v = strtoul(s, &end, 0);
    if (*s == '\0' || *end != '\0') {
        return 0;
    }

    *value = (uint32_t)v;
    return 1;
}

static int parse_size_arg(const char *s, size_t *value)
{
    unsigned long v;
    char *end;

    if (s == NULL || value == NULL) {
        return 0;
    }

    v = strtoul(s, &end, 0);
    if (*s == '\0' || *end != '\0') {
        return 0;
    }

    *value = (size_t)v;
    return 1;
}

static int parse_options(int argc, char **argv, app_options_t *opts, int *cmd_index)
{
    int i;

    opts->base_addr = RV32I_MLA_DEFAULT_BASE;
    opts->map_size = RV32I_MLA_DEFAULT_SIZE;
    opts->wait_ms = APP_WAIT_MS_DEFAULT;
    opts->try_run = 0;

    for (i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--base") == 0) {
            if ((i + 1) >= argc || !parse_u32_arg(argv[i + 1], &opts->base_addr)) {
                return 0;
            }
            ++i;
            continue;
        }
        if (strcmp(argv[i], "--size") == 0) {
            if ((i + 1) >= argc || !parse_size_arg(argv[i + 1], &opts->map_size)) {
                return 0;
            }
            ++i;
            continue;
        }
        if (strcmp(argv[i], "--wait-ms") == 0) {
            uint32_t tmp;
            if ((i + 1) >= argc || !parse_u32_arg(argv[i + 1], &tmp)) {
                return 0;
            }
            opts->wait_ms = (unsigned)tmp;
            ++i;
            continue;
        }
        if (strcmp(argv[i], "--try-run") == 0) {
            opts->try_run = 1;
            continue;
        }

        *cmd_index = i;
        return 1;
    }

    return 0;
}

int main(int argc, char **argv)
{
    rv32i_mla_dev_t *dev;
    int rc = 1;
    int cmd_index = -1;
    app_options_t opts;
    uint32_t smoke_prog[3];
    uint32_t no_branch_prog[7];
    uint32_t branch_only_prog[10];
    uint32_t jump_only_prog[9];
    diag_test_t tests[] = {
        {"smoke",       "Minimal execute/store sanity check", smoke_prog,       3U, 1, 12U, 0, 0U},
        {"no_branch",   "Final store path without branch/jump", no_branch_prog, 7U, 1, 12U, 1, 2U},
        {"branch_only", "BEQ compare + target handling", branch_only_prog, 10U, 1, 12U, 1, 2U},
        {"jump_only",   "JAL target handling", jump_only_prog, 9U, 1, 12U, 1, 2U}
    };
    diag_test_t *selected;

    init_programs(smoke_prog, no_branch_prog, branch_only_prog, jump_only_prog);

    if (argc < 2 || !parse_options(argc, argv, &opts, &cmd_index)) {
        print_usage(argv[0]);
        return 1;
    }

    dev = rv32i_mla_open(opts.base_addr, opts.map_size);
    if (dev == NULL) {
        fprintf(stderr, "rv32i_mla_open failed\n");
        return 1;
    }

    if (strcmp(argv[cmd_index], "info") == 0) {
        rc = app_print_info(dev);
        goto out;
    }
    if (strcmp(argv[cmd_index], "ps_sanity") == 0) {
        rc = app_ps_sanity(dev);
        goto out;
    }
    if (strcmp(argv[cmd_index], "dump_imem") == 0) {
        size_t words = 8U;
        if ((cmd_index + 1) < argc) {
            words = (size_t)strtoul(argv[cmd_index + 1], NULL, 0);
        }
        rc = app_dump_imem(dev, words);
        goto out;
    }
    if (strcmp(argv[cmd_index], "dump_dmem") == 0) {
        size_t words = 8U;
        if ((cmd_index + 1) < argc) {
            words = (size_t)strtoul(argv[cmd_index + 1], NULL, 0);
        }
        rc = app_dump_dmem(dev, words);
        goto out;
    }
    if (strcmp(argv[cmd_index], "results") == 0) {
        rc = app_print_results(dev);
        goto out;
    }
    if (strcmp(argv[cmd_index], "stage_bin") == 0) {
        if ((cmd_index + 1) >= argc) {
            fprintf(stderr, "stage_bin requires a .bin path\n");
            goto out;
        }
        rc = app_stage_bin(dev, argv[cmd_index + 1], &opts);
        goto out;
    }

    selected = find_test(argv[cmd_index], tests, sizeof(tests) / sizeof(tests[0]));
    if (selected != NULL) {
        rc = app_stage_words(dev, selected, &opts);
        if (rc == 0) {
            rc = app_check_expectations(dev, selected);
        }
        goto out;
    }

    fprintf(stderr, "unknown command: %s\n", argv[cmd_index]);
    print_usage(argv[0]);

out:
    rv32i_mla_close(dev);
    return rc;
}
