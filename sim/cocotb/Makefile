# Builds RV32I assembly programs and runs the cpu_top cocotb tests.

REPO      := $(abspath $(CURDIR)/../..)
BUILD     := $(CURDIR)/build
RV_PREFIX ?= riscv64-unknown-elf-
RV_FLAGS  := -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -mno-relax -Wl,--no-relax
ASM_DIR   := $(REPO)/sw/tests/asm
RT_DIR    := $(REPO)/sw/tests/riscv-tests
ELFS      := $(patsubst $(ASM_DIR)/%.S,$(BUILD)/%.elf,$(wildcard $(ASM_DIR)/*.S)) \
             $(patsubst $(RT_DIR)/isa/rv32ui/%.S,$(BUILD)/rv32ui_%.elf,$(wildcard $(RT_DIR)/isa/rv32ui/*.S))

SIM                 ?= icarus
TOPLEVEL_LANG       := verilog
CPU                 := $(REPO)/RV32I-MLA.srcs/sources_1/new/cpu_top.v
VERILOG_SOURCES     := $(CPU)
TOPLEVEL            := cpu_top
MODULE              := test_cpu
export PROGRAM_DIR  := $(BUILD)

# $(call run,suite,module,toplevel,sources) runs one cocotb suite; $(call judge,suite) checks its results.
run   = rm -f $(BUILD)/$(1)_$(SIM).json && $(MAKE) sim MODULE=$(2) TOPLEVEL=$(3) VERILOG_SOURCES=$(4) SIM_BUILD=$(BUILD)/sim_build_$(3)_$(SIM) COCOTB_RESULTS_FILE=$(BUILD)/$(1)_$(SIM).xml MANIFEST=$(BUILD)/$(1)_$(SIM).json
judge = $(PYTHON_BIN) check_results.py $(BUILD)/$(1)_$(SIM).xml $(BUILD)/$(1)_$(SIM).json

.PHONY: test model cpu harness isa programs

test: model cpu harness

model: programs
	$(PYTHON_BIN) -m unittest test_memory_model test_check_results
	$(PYTHON_BIN) check_programs.py $(ASM_DIR) $(BUILD)

cpu: programs
	$(call run,baseline,test_cpu,cpu_top,$(CPU))
	$(call judge,baseline)

harness:
	$(call run,harness,test_harness,stub_cpu,$(CURDIR)/stub_cpu.v)
	$(call judge,harness)

isa: programs
	$(call run,isa,test_isa,cpu_top,$(CPU))
	$(call judge,isa) --known known_failures.txt --coverage coverage.csv --out $(BUILD)/coverage_$(SIM).csv

programs: $(ELFS)

$(BUILD)/%.elf: $(ASM_DIR)/%.S $(ASM_DIR)/isa.h $(REPO)/sw/linker.ld
	@mkdir -p $(BUILD)
	$(RV_PREFIX)gcc $(RV_FLAGS) -I$(ASM_DIR) -T $(REPO)/sw/linker.ld -Wl,-Map=$(BUILD)/$*.map $< -o $@
	$(RV_PREFIX)objdump -d -M no-aliases $@ > $(BUILD)/$*.dump

$(BUILD)/rv32ui_%.elf: $(RT_DIR)/isa/rv32ui/%.S $(RT_DIR)/isa/rv64ui/%.S $(RT_DIR)/env/riscv_test.h $(RT_DIR)/isa/macros/scalar/test_macros.h $(RT_DIR)/link.ld
	@mkdir -p $(BUILD)
	$(RV_PREFIX)gcc $(RV_FLAGS) -I$(RT_DIR)/env -I$(RT_DIR)/isa/macros/scalar -T $(RT_DIR)/link.ld -Wl,-Map=$(BUILD)/rv32ui_$*.map $< -o $@
	$(RV_PREFIX)objdump -d -M no-aliases $@ > $(BUILD)/rv32ui_$*.dump

include $(shell cocotb-config --makefiles)/Makefile.sim
